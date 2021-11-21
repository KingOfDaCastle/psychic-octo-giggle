##############################################################################################################
#!/bin/bash
# Flush IPTables
for chain in INPUT OUTPUT FORWARD
do
        sudo iptables -P "${chain}" ACCEPT
done
sudo iptables -t filter -F
sudo iptables -t nat -F

# INPUT Chain
sudo iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -m conntrack --ctstate INVALID -j DROP
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -p ICMP -j ACCEPT

read -p "How many TCP INPUT ports do you want open? " NUMTCPPORTS
if [ "${NUMTCPPORTS}" -ne 0 ]
then
        if [ "${NUMTCPPORTS}" -gt 1 ]
        then
                read -p  "Which TCP INPUT ports do you want open? " TCPPORT
                sudo iptables -A INPUT -p tcp -m multiport  --dports ${TCPPORT} -m conntrack --ctstate NEW -j ACCEPT

        else
                read -p "Which TCP INPUT port do you want open? " TCPPORT
                sudo iptables -A INPUT -p tcp  --dport ${TCPPORT} -m conntrack --ctstate NEW -j ACCEPT
        fi
fi
read -p "How many UDP INPUT ports do you want open? " NUMUDPPORTS
if [ "${NUMUDPPORTS}" -ne 0 ]
then
        if [ "${NUMUDPPORTS}" -gt 1 ]
        then
                read -p  "Which UDP INPUTS ports do you want open? " UDPPORT
                sudo iptables -A INPUT -p udp -m multiport  --dports ${UDPPORT} -j ACCEPT

        else
                read -p "Which UDP INPUT port do you want open? " UDPPORT
                sudo iptables -A INPUT -p udp  --dport ${UDPPORT} -j ACCEPT
        fi
fi
sudo iptables -A INPUT -j LOG --log-prefix "iptables INPUT dropped: "
# OUTPUT Chain
sudo iptables -A OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A OUTPUT -m conntrack --ctstate INVALID -j DROP
sudo iptables -A OUTPUT -o lo -j ACCEPT
sudo iptables -A OUTPUT -p icmp -j ACCEPT

read -p "How many TCP OUTPUT ports do you want open? " NUMTCPPORTS
if [ "${NUMTCPPORTS}" -ne 0 ]
then
        if [ "${NUMTCPPORTS}" -gt 1 ]
        then
                read -p  "Which TCP OUTPUT ports do you want open? " TCPPORT
                sudo iptables -A OUTPUT -p tcp -m multiport  --dports ${TCPPORT} -m conntrack --ctstate NEW -j ACCEPT

        else
                read -p "Which TCP OUTPUT port do you want open? " TCPPORT
                sudo iptables -A OUTPUT -p tcp  --dport ${TCPPORT} -m conntrack --ctstate NEW -j ACCEPT
        fi
fi

read -p "How many UDP OUTPUT ports do you want open? " NUMUDPPORTS
if [ "${NUMUDPPORTS}" -ne 0 ]
then
        if [ "${NUMUDPPORTS}" -gt 1 ]
        then
                read -p  "Which UDP OUTPUT ports do you want open? " UDPPORT
                sudo iptables -A OUTPUT -p udp -m multiport  --dports ${UDPPORT} -j ACCEPT

        else
                read -p "Which UDP OUTPUT port do you want open? " UDPPORT
                sudo iptables -A OUTPUT -p udp  --dport ${UDPPORT} -j ACCEPT
        fi
fi
sudo iptables -A OUTPUT -j LOG --log-prefix "iptables OUTPUT dropped: "
read -p "Do you want to configure forwarding rules? (Y/n) " answer

if [ "${answer}" = 'n' ] || [ "${answer}" = 'N' ];
then 

	echo " No forwarding rules configured"

else

	sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -A FORWARD -m conntrack --ctstate INVALID -j DROP
	echo "Available Interfaces:"
	ip a | grep mtu | awk '{print $2}' | cut -d ':' -f1 | grep -v lo
	read -p "Eneter tunnel interface name " input
	echo "Available Interfaces:"
	ip a | grep mtu | awk '{print $2}' | cut -d ':' -f1 | grep -v lo
	read -p "Enter outbound interface " outbound
	echo "Available Interfaces:"
	ip a | grep mtu | awk '{print $2}' | cut -d ':' -f1 | grep -v lo
	tunNet=$(ip r | grep ${input} | cut -d ' ' -f1)
	sudo iptables -A FORWARD -i ${input} -o ${outbound} -s ${tunNet} -m comment --comment "Allow new traffic from VPN subnet to internet" -j ACCEPT
	sudo iptables -A FORWARD -j LOG --log-prefix "iptables forward dropped: "
	sudo iptables -t nat -A POSTROUTING -s ${tunNet} -o ${outbound} -j MASQUERADE

fi

read -p "Do you want to forward IPv4? (Y/n) " answer
if [ "${answer}" = 'n' ] || [ "${answer}" = 'N' ];
then
	echo "IPv4 forwarding NOT enabled"
else
	sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf && sudo sysctl -p
fi

# Default Policies
for chain in INPUT OUTPUT
do
        sudo iptables -P "${chain}" DROP
done

echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean false | sudo debconf-set-selections
sudo apt install iptables-persistent -y
sudo iptables-save | sudo tee /etc/iptables/rules.ipv4

