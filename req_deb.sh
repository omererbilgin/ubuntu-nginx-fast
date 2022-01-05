#!/bin/bash

#Install packages:

#cant install all these with root
#better to avoid the pain in the ass

if [[ $EUID -ne 0 ]]
  then

  echo 'Run as root!'
  echo 'Executing (sudo su)' && sudo su

fi

apt update

#print echo
ecco () {
  i=0
  while [ $i -lt $1 ]
    do
    echo
    ((i++))
  done
}

check_pack () {

  if [[ $? -ne 0 ]]
    then
    ecco 2
    echo "Couldn't install $1"
    ecco 1
    sleep 1
    echo 'Trying to add PPA...'
    ecco 1

    if [[ "$1" == "curl" ]]
      then
      
      apt install add-apt-repository -y

      if [[ $? -ne 0 ]]
         then
         ecco 1
         apt install -y software-properties-common
         
         if [[ $? -ne 0 ]]
            then
            ecco 2
            echo 'Cant install packages (ABORT)'
            exit
         fi
         
         apt install -y add-apt-repository && ecco 2
      
      fi

      apt update -y
      add-apt-repository -y ppa:kelleyk/curl
    
    fi

    if [[ "$1" == "nginx" ]]
      then
      add-apt-repository ppa:nginx/stable
    fi

    if [[ "$1" == "php" ]]
      then
      add-apt-repository -y ppa:sergey-dryabzhinsky/php80
    fi


    if [[ "$1" == "python3" ]]
      then
      add-apt-repository -y ppa:deadsnakes/ppa  
    fi
    
    apt update -y
    apt install $1 -y 
 
  fi

}

apt update
apt install -y curl && check_pack "curl"
apt install -y wget nginx && check_pack "nginx" 
apt install -y php && check_pack "php" 
apt install -y python3 && check_pack "python3"
apt install -y gcc
apt install -y php-fpm php-cli php-mysql php-curl php-json -y

ecco 3 && echo $(ufw app list) && ecco 3

read -p "Enable NGINX SERVER on UFW? [Y][n] " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]
  then
  ufw allow "Nginx Full"
  ecco 2
  echo -n "UFW FIREWALL" $(ufw status)

else
  ecco 2
  echo "Skipping FIREWALL settings..."
fi

ecco 2
#disable apache2
systemctl disable apache2
systemctl stop apache2

#basic
systemctl stop nginx
systemctl start nginx
systemctl restart nginx
systemctl reload nginx
systemctl status nginx -l --no-pager 
systemctl enable nginx

ecco 3
read -p "Save HOST NETWORK Information? [Y]/[n] " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]
  then
  ecco 2
  touch host.list
  echo $(hostname -I) >> host.list
  echo 'Saved...'

else
  
  ecco 2
  echo "Skipping enlisting..."

fi

ecco 2
read -p "Config Certbot? [y][N] " -n 1 -r
ecco 1

if [[ ! $REPLY =~ ^[Nn]$ ]]
  then
  
  apt install -y certbot && check_pack "certbot" 
  apt install -y python3-certbot-nginx && check_pack "python3-certbot-nginx"
  
  if [[ $? -ne 0 ]]
    then
    ecco 2
    echo "Can't install certbot... (Configure PPA manually)"
  
  else
  
    ecco 2
    echo 'For SSL CERT:'
    ecco 2
    echo 'Config at: /etc/nginx/sites-available/*file*'
    echo '&&'
    echo 'Create symlink to /etc/nginx/sites-enabled/*'
    ecco 2
    echo 'Dont forget to add CNAME records!'
    read -p "Add auto for port: 80? [y][N] " -n 1 -r
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]
      then
    
      ecco 2
      echo -n 'Domain (format: example.com): '
      read domain
      ecco 1
      echo -n 'Subdomain (format: examplename || blank): '
      read subtmp
      ecco 1
      echo -n 'File name (not path): '
      read file
      if [[ "$subtmp" = "" ]]
        then
    
        sub=""
    
      else
    
        sub=$(echo -n $subtmp'.')
    
      fi
    
    echo """
server {

        listen 80 ;
        listen [::]:80 ;

        root /var/www/mail;
        index index.html index.htm index.nginx-debian.hmtl;

        server_name $domain www.$domain $sub$domain www.$sub$domain ;

        location / { 
                try_files $uri $uri/ =404;
        }
        location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        }
}
    """ >> /etc/nginx/sites-available/$file
    # creating symlink
    ln -s /etc/nginx/sites-available/$file /etc/nginx/sites-enabled/
    
    ecco 2
    systemctl reload nginx
    echo -n 'Nginx Config Test... '
    nginx -t
    systemctl reload nginx
    ecco 3
    
    if [ $? -ne 0 ]
      then
      echo 'Config syntax correct! You can later change your config file at: /etc/nginx/sites-available/$file'   
    else
      echo "$(tput setaf 1)$(tput setab 7)WARNING: Config syntax unfortunately wrong! You can later change your config file at: /etc/nginx/sites-available/$file $(tput sgr 0)"
      echo 'Its not recommended to run Certbot'
    fi
    
    fi
    ecco 3
    read -p "Run Certbot? [y][N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]
      then
      ecco 2
      read -p "Use email to get notifications? [y][N] " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Nn]$ ]]
        then
        certbot --nginx
      else
        certbot --nginx --register-unsafely-without-email
      fi
    fi    
  fi
  
echo
    
else
    ecco 2
    echo "Skipping certbot..."
fi


ecco 4
echo 'Finished!'
exit
