# must match the Lambda runtime the functions use (provided.al2023), and RUNTIME_IMAGE in build.sh
FROM public.ecr.aws/lambda/provided:al2023

# install the highest PHP stream (phpX.Y) available in the latest Amazon Linux repo release,
# rather than whichever version Amazon has chosen as the default for the unversioned "php" package
RUN PHP=$(dnf --releasever=latest repoquery 'php[0-9]*' 2>/dev/null \
      | grep -oE '^php[0-9]+\.[0-9]+' \
      | sort -uV \
      | tail -n 1) \
 && test -n "$PHP" \
 && echo "Installing $PHP" \
 && dnf install -y --releasever=latest "$PHP" "$PHP-mysqlnd" "$PHP-intl" \
 && dnf clean all
