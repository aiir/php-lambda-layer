# PHP Runtime Layer for AWS Lambda

This runtime layer aims to replicate the typical web server environment for executing PHP scripts within AWS Lambda, so that an Lambda function can be used as an alternative hosting environment for a PHP-based site.

This layer utilises the PHP CGI runtime to replicate the environment offered in other runtime setups such as PHP FPM.

## Usage

### General Usage

A Lambda function using this runtime layer is intended to sit behind either an Application Load Balancer or API Gateway, providing an HTTP interface in to the function.

The layer runs a PHP CGI process for each incoming request, executing either a PHP script whose path matches the incoming HTTP request or alternativing using the script at the path configured as the handler for the Lambda function.

The bootstrap is responsible for obtaining an incoming request, re-formatting it from the ALB/Gateway event object in to a format that the PHP process understands, executing the script, then re-formatting the response back to a format that AWS can return to the originating requester.

### Configuration

The layer will attempt to load `php.ini` from inside your Lambda function distribution at the root level.

You can enable access logging by declaring the environment variable `ACCESS_LOG` and setting the value to `true`.

You can optionally format the output by declaring the `ACCESS_FORMAT` variable. It can take the following arguments:

```
%m: request method
%r: the request URI (without the query string, see %q and %Q)
%Q: the '?' character if query string exists
%q: the query string
%s: status (response code)
%f: script filename
%d: time taken to serve the request in seconds
%e: an environment variable (same as $_ENV or $_SERVER)
    it must be associated with embraces to specify the name of the env
    variable. Some exemples:
    - server specifics like: %{REQUEST_METHOD}e or %{SERVER_PROTOCOL}e
    - HTTP headers like: %{HTTP_HOST}e or %{HTTP_USER_AGENT}e
```

The default value is `"%m %r%Q%q" %s %f %d`.

### Extensions
The following extensions are built into the layer and available in `/opt/lib/php/7.x/modules` (where x is the current minor version):

```
bz2.so
calendar.so
ctype.so
curl.so
dom.so
exif.so
fileinfo.so
ftp.so
gettext.so
iconv.so
json.so
mbstring.so
mysqli.so
mysqlnd.so
pdo.so
pdo_mysql.so
pdo_sqlite.so
phar.so
simplexml.so
sockets.so
sqlite3.so
tokenizer.so
wddx.so
xml.so
xmlreader.so
xmlwriter.so
xsl.so
```

These extensions are not loaded by default. You must add the extension to a php.ini file to use it:

```ini
extension=json.so
```

It is recommended that custom extensions be provided by a separate Lambda Layer with the extension .so files placed in `/lib/php/7.x/modules/` so they can be loaded alongside the built-in extensions listed above.

### Amazon Linux 2

The PHP 7.4 layer is targeted to an environment running Amazon Linux 2. It may run on an earlier version, but you are encourage to run it against v2.

At the time of publication Lambda defaults to containers running 1.x variants of Amazon's own Linux distribution. To force your Lambda to run on Amazon Linux 2, you must add the following "fake" Lambda Layer to your function:

```
arn:aws:lambda:::awslayer:AmazonLinux2
```

## Development

### Testing

A basic PHPUnit functional test case is provided for the bootstrap. You can run this either locally (although this will target your local machines PHP environment), or within Docker where it utilises a built version of the layer.

To run locally, simply:

```
composer test
```

To run within Docker:

```
make test
```

### Building

To build the layer zip package you will need to have Docker available on your machine. Once ready, simply run the relevant `Makefile` command for the version of PHP you require, either:

```
make php73.zip
```

or

```
make php74.zip
```

This will launch a Docker container and build a layer zip file for you in the current directory.

## Disclaimer

> THIS SOFTWARE IS PROVIDED BY THE PHP DEVELOPMENT TEAM ``AS IS'' AND
> ANY EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
> THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
> PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE PHP
> DEVELOPMENT TEAM OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
> INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
> (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
> SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
> HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
> STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
> ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
> OF THE POSSIBILITY OF SUCH DAMAGE.
