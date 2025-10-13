FROM wordpress:latest

# Activer les modules nécessaires
RUN a2enmod rewrite headers

# Autoriser les .htaccess dans /var/www/html
RUN sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf

# Configuration pour HTTPS derrière un proxy
RUN echo 'SetEnvIf X-Forwarded-Proto "^https$" HTTPS=on\n\
RemoteIPHeader X-Forwarded-For\n\
RemoteIPInternalProxy 10.0.0.0/8\n\
RemoteIPInternalProxy 172.16.0.0/12\n\
RemoteIPInternalProxy 192.168.0.0/16\n\
ServerTokens Prod\n\
ServerSignature Off' > /etc/apache2/conf-available/proxy-https.conf \
    && a2enconf proxy-https
