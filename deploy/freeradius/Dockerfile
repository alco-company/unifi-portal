# FROM freeradius/freeradius-server:3.2.5
FROM freeradius/freeradius-dev:arm64v8-v3.2.x-alpine
COPY raddb_local/ /etc/raddb
COPY startup.sh /config/startup.sh
EXPOSE 1812/udp 1813/udp
CMD ["sh","/config/startup.sh"]