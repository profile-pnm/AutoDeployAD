# Install samba-dc and provision master into LXC container
apt-get install samba-dc

rm -rf /etc/samba/smb.conf
samba-tool domain provision --domain DEV --realm=dev.srt.basealt.ru --site infra --dns-backend=SAMBA_INTERNAL --server-role=dc --function-level=2016 --use-rfc2307 --backend-store=mdb --option="ad dc functional level = 2016"
sed -i '/\[global\]/a \\tad dc functional level = 2016' /etc/samba/smb.conf

systemctl enable samba.service
systemctl start samba.service

# Install bind dns
apt-get install bind
control bind-chroot disabled
sed -i '/options {/a \\ttkey-gssapi-keytab "/var/lib/samba/bind-dns/dns.keytab";' /etc/bind/options.conf
sed -i '/options {/a \\tminimal-responses yes;' /etc/bind/options.conf
sed -i -E 's/^([ \t]*)(listen-on\s+\{.*\};)$/\1\/\/\2/g' /etc/bind/options.conf
sed -i -E 's/^([ \t]*)(listen-on-v6\s+\{.*\};)$/\1\/\/\2/g' /etc/bind/options.conf
sed -i -E 's/^([ \t]*)\/\/(forwarders\s+\{).*(\};)$/\1\2 10.64.224.3; 10.64.0.16; 10.64.0.17; \3/g' /etc/bind/options.conf
sed -i -E 's/^([ \t]*)\/\/(allow-query\s+\{).*(\};)$/\1\2 any; \3/g' /etc/bind/options.conf
sed -i -E 's/^([ \t]*)\/\/(allow-recursion\s+\{).*(\};)$/\1\2 any; \3/g' /etc/bind/options.conf
echo 'include "/var/lib/samba/bind-dns/named.conf";' >> /etc/bind/named.conf
sed -i -E '/\[global\]/a \\tserver services = -dns' /etc/samba/smb.conf

systemctl stop samba
systemctl start bind
systemctl start samba

# Domain auth in DC
apt-get install task-auth-ad-winbind gpupdate alterator-roles-common
sed -i -E 's/^[ #]?(dns_lookup_realm)\s+=\s+[a-zA-Z]+$/ \1 = false/' /etc/krb5.conf
sed -i -E 's/^[ #]+(default_realm)\s+=\s+[a-zA-Z.-]+$/ \1 = DEV.SRT.BASEALT.RU/' /etc/krb5.conf

/etc/samba/smb.conf:
    [Global]
        ## Local domain auth
        kerberos method = dedicated keytab
        dedicated keytab file = /etc/krb5.keytab
        template shell = /bin/bash
        template homedir = /home/%D/%U
        wins support = no
        winbind use default domain = yes
        winbind enum users = no
        winbind enum groups = no
        winbind refresh tickets = yes
        winbind offline logon = yes

/etc/nsswitch.conf:
    passwd:     files winbind systemd
    shadow:     tcb files winbind
    group:      files [SUCCESS=merge] winbind systemd role

control system-auth winbind
control sudowheel enabled
net ads keytab create
roleadd 'domain users' users
roleadd 'domain admins' localadmins
systemctl restart samba.service
gpupdate-setup enable --local-policy ad-domain-controller