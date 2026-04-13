FROM node:20.3.1 as builder

WORKDIR /app
ADD package*.json ./
RUN apt-get -qq update
RUN apt-get -qq install netbase build-essential autoconf libffi-dev
RUN npm ci --production

ADD . .
RUN npm run build

FROM nginx:1

# INSTALL JQ for the set-dashboard-config.sh script
RUN apt-get update -qq && apt-get install -qq -y jq && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/build/ /usr/share/nginx/html/
ADD default.conf /etc/nginx/conf.d/
ADD config.json.template /usr/share/nginx/html/config.json.template

ADD set-dashboard-config.sh /docker-entrypoint.d/set-dashboard-config.sh
RUN chmod +x /docker-entrypoint.d/set-dashboard-config.sh
