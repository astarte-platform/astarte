FROM node:8-stretch as builder

WORKDIR /app
ADD . .
RUN apt-get -qq update
RUN apt-get -qq install netbase build-essential autoconf libffi-dev
RUN npm install
RUN npm run deploy

FROM nginx:1.13
COPY --from=builder /app/dist/ /usr/share/nginx/html/
ADD default.conf /etc/nginx/conf.d/
