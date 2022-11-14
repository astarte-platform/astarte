FROM node:16.18.1 as builder

WORKDIR /app
ADD . .
RUN apt-get -qq update
RUN apt-get -qq install netbase build-essential autoconf libffi-dev
RUN npm ci
RUN npm run deploy

FROM nginx:1
COPY --from=builder /app/dist/ /usr/share/nginx/html/
ADD default.conf /etc/nginx/conf.d/
