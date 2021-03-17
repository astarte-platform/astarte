FROM node:14 as builder

WORKDIR /app
ADD . .
RUN apt-get -qq update
RUN apt-get -qq install netbase build-essential autoconf libffi-dev
RUN npm install
RUN npm run deploy

FROM nginx:1
COPY --from=builder /app/build/ /usr/share/nginx/html/
ADD default.conf /etc/nginx/conf.d/
