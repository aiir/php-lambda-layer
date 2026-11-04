# PHP Runtime Layer for AWS Lambda

This runtime layer aims to replicate the typical web server environment for executing PHP scripts within AWS Lambda, so that an Lambda function can be used as an alternative hosting environment for a PHP-based application.

This layer utilises the PHP CGI runtime to replicate the environment offered in other runtime setups such as PHP FPM.

## Usage

### General Usage

A Lambda function using this runtime layer is intended to sit behind either an Application Load Balancer or API Gateway, providing an HTTP interface in to the function.

The layer runs a PHP CGI process for each incoming request, executing either a PHP script whose path matches the incoming HTTP request or alternatively using the script at the path configured as the handler for the Lambda function.

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

When building, the default extensions for the most recent PHP version will be included in `/opt/lib/php/modules`.

These extensions are not loaded by default. You must add the extension to a `php.ini` file to use it, e.g.

```ini
extension=dom.so
```

It is recommended that additional extensions be provided by a separate Lambda Layer with the extension .so files placed in the `/lib/php/modules` directory so they can be loaded alongside the built-in extensions listed above.

### Time Zone Data

The time zone data in Amazon Linux lags behind tz releases, so the build bundles the latest available for both of PHP's time zone databases:

- PHP's date functions use the [`timezonedb`](https://pecl.php.net/package/timezonedb) extension, which the layer always loads. PHP only uses its data when it is newer than the system's `tzdata`. Do not add `extension=timezonedb.so` to your own `php.ini`, as loading it twice causes a warning on every request.
- ICU (used by the `intl` extension) uses the latest ICU time zone data from [unicode-org/icu-data](https://github.com/unicode-org/icu-data), bundled in `/opt/icu-tz`. The bootstrap points ICU at it by setting `ICU_TIMEZONE_FILES_DIR`, unless the function sets that variable itself.

### Architecture

`arm64` is the target architecture for this Lambda layer.

## Development

### Building

The build process requires Docker to boot a container provided by Amazon which replicates the current Lambda environment.

With a system that has Docker installed, run `./build.sh`. This script will build a new Docker image from the Amazon-supplied one, launch a container and then copy the required files for PHP to execute on Lambda from the container to the local file system, before creating a zip file.

The resulting `layer.zip` file is your final Lambda layer.

### Testing

In the `test` directory is as `run.sh` script which will launch the Amazon-supplied Lambda environment container on a local Docker install, supplying the most recent layer build on your local system to it.

This will result in an HTTP server on port 9000 which mimics the Lambda environment, ready to receive invocation requests.

The second script in this directory, `request.sh`, provides an example of how to send a request to the HTTP server.

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
