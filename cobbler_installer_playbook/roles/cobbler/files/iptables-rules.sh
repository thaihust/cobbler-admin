iptables -D INPUT -j REJECT --reject-with icmp-host-prohibited
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 69 -j ACCEPT
iptables -A INPUT -m state --state NEW -m udp -p udp --dport 69 -j ACCEPT
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -m state --state NEW -m tcp -p tcp --dport 25151 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables-save
/usr/libexec/iptables/iptables.init save
