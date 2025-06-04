#fullstack_user_data.tf

#!/bin/bash
exec > >(tee /var/log/user-data.log) 2>&1
echo "🔧 Pokrećem provisioning..."

# Ažuriraj sistem i instaliraj alate
yum update -y
amazon-linux-extras enable docker
yum install -y docker git curl
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Kloniraj repozitorij
mkdir -p /opt/webapp
rm -rf /opt/webapp/*
cd /opt/webapp
git clone https://github.com/hasicamina/projekat2-iso .

# Pokreni aplikaciju koristeći tvoju skriptu
chmod +x pokreni_aplikaciju.sh
./pokreni_aplikaciju.sh >> /var/log/pokreni.log 2>&1

echo "✅ Aplikacija pokrenuta preko tvoje skripte!"
