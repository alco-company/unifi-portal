# FROM freeradius/freeradius-server:3.2.5
FROM freeradius/freeradius-dev:arm64v8-v3.2.x-alpine
COPY raddb_local/ /etc/raddb
COPY start.sh /config/start.sh
EXPOSE 1812/udp 1813/udp
CMD ["sh","/config/start.sh"]