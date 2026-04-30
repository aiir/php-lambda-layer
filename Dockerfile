FROM public.ecr.aws/lambda/provided:latest

RUN dnf install -y php php-mysqlnd php-intl
