<?php
namespace Aiir\PHPLambdaLayer;

use donatj\MockWebServer\MockWebServer;
use donatj\MockWebServer\Response;
use PHPUnit\Framework\TestCase;

/**
 * Functional tests for PHP Lambda Layer custom runtime bootstrap.
 */
final class BootstrapTest extends TestCase
{
    /** @var MockWebServer */
    protected static $server;

    /**
     * Sets up a mock web server to replicate the Lambda runtime API and loads
     * the bootstrap, setting the environment variables AWS set.
     */
    public static function setUpBeforeClass(): void
    {
        self::$server = new MockWebServer;
        self::$server->start();

        putenv('AWS_LAMBDA_RUNTIME_API=' . self::$server->getHost() . ':' . self::$server->getPort());
        putenv('LAMBDA_TASK_ROOT=' . __DIR__ . '/_files');
        putenv('MAX_EXECUTION_TIME=5');
        if (!file_exists('/var/task/php.ini')) {
            // use default environment settings if not running inside test container
            putenv('CONFIG_PATH=/dev/null');
        }
        putenv('_HANDLER=public/index.php');
        $loop = false;

        ob_start(); // capture output to avoid echo'ing the shebang at top of bootstrap
        if (file_exists('/opt/bootstrap')) {
            require '/opt/bootstrap';
        } else {
            require __DIR__ . '/../bootstrap';
        }
        ob_end_clean();
    }

    /**
     * Helper function for setting the next response from the Lambda runtime API
     * next invocation endpoint.
     */
    private function setNextInvocation(array $response): string
    {
        $id = sprintf(
            '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
            mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0x0fff) | 0x4000,
            mt_rand(0, 0x3fff) | 0x8000,
            mt_rand(0, 0xffff),
            mt_rand(0, 0xffff),
            mt_rand(0, 0xffff)
        );

        $body = json_encode($response);
        $headers = ['Lambda-Runtime-Aws-Request-Id' => $id];
        self::$server->setResponseOfPath(
            '/' . LAMBDA_RUNTIME_API_VERSION . '/runtime/invocation/next',
            new Response($body, $headers, 200)
        );

        return $id;
    }

    /**
     * Helper function for getting and decoding the last response sent to the
     * Lambda runtime API invocation response endpoint.
     */
    private function getInvocationResponse(): \stdclass
    {
        $request = self::$server->getLastRequest();
        if ($request === null) {
            $error = new \Exception('No request received');
            throw $error;
        }

        $body = $request->getInput();
        $response = json_decode($body);

        return $response;
    }

    /**
     * Calls the root path and ensures we get the home page.
     */
    public function testGetRoot(): void
    {
        $this->setNextInvocation([
            'requestContext' => [],
            'httpMethod' => 'GET',
            'path' => '/',
            'body' => '',
        ]);

        $invocation = handleNextRequest();

        $response = $this->getInvocationResponse();
        $this->assertEquals(200, $response->statusCode);
        $this->assertEquals('Home', $response->body);
    }

    /**
     * ???
     */
    public function testPostRoot(): void
    {
        $this->setNextInvocation([
            'requestContext' => [],
            'httpMethod' => 'POST',
            'headers' => [
                'content-type' => 'application/x-www-form-urlencoded; charset=UTF-8',
            ],
            'path' => '/',
            'body' => 'foo=bar&bar=foo',
        ]);

        $invocation = handleNextRequest();

        $response = $this->getInvocationResponse();
        $this->assertEquals('barfoo', $response->body);
    }

    /**
     * Calls a path handled by the dynamic routing and ensure the correct
     * response is returned.
     */
    public function testRouterPath(): void
    {
        $this->setNextInvocation([
            'requestContext' => [],
            'httpMethod' => 'GET',
            'path' => '/foo/bar/baz',
            'body' => '',
        ]);

        $invocation = handleNextRequest();

        $response = $this->getInvocationResponse();
        $this->assertEquals('foo/bar/baz', $response->body);
    }

    /**
     * Calls a path that refers to an explicit PHP script and ensure the
     * correct response is returned.
     */
    public function testExplicitPath(): void
    {
        $this->setNextInvocation([
            'requestContext' => [],
            'httpMethod' => 'GET',
            'path' => '/subdir/index.php',
            'body' => '',
        ]);

        $invocation = handleNextRequest();

        $response = $this->getInvocationResponse();
        $this->assertEquals(200, $response->statusCode);
        $this->assertEquals('subdir', $response->body);
    }

    /**
     * Calls the boostrap as if the incoming event is coming from API Gateway
     * (no `requestContext` property), ensuring `statusDescription` is not set.
     */
    public function testNoStatusDescriptionHeaderForAPIGateway(): void
    {
        $this->setNextInvocation([
            'httpMethod' => 'GET',
            'path' => '/',
            'body' => '',
        ]);

        $invocation = handleNextRequest();

        $response = $this->getInvocationResponse();
        $this->assertFalse(property_exists($response, 'statusDescription'));
    }

    /**
     * Calls the boostrap as if the incoming event is coming from ALB (includes
     * a `requestContext` property), ensuring `statusDescription` is set.
     */
    public function testStatusDescriptionHeaderForALBRequest(): void
    {
        $this->setNextInvocation([
            'requestContext' => [],
            'httpMethod' => 'GET',
            'path' => '/',
            'body' => '',
        ]);

        $invocation = handleNextRequest();

        $response = $this->getInvocationResponse();
        $this->assertEquals('200 OK', $response->statusDescription);
    }

    /**
     * Calls the bootstrap with a path that matches a directory inside the
     * handler path that contains an index.php script.
     */
    public function testSubDirectoryWithIndex(): void
    {
        $this->setNextInvocation([
            'requestContext' => [],
            'httpMethod' => 'GET',
            'path' => '/subdir/',
            'body' => '',
        ]);

        $invocation = handleNextRequest();

        $response = $this->getInvocationResponse();
        $this->assertEquals('subdir', $response->body);
    }

    /**
     * Requests a path that matches a directory inside the handler path that
     * contains an index.php script, but without a trailing slash.
     */
    public function testSubDirectoryWithIndexWithoutTrailingSlash(): void
    {
        $this->setNextInvocation([
            'requestContext' => [],
            'httpMethod' => 'GET',
            'path' => '/subdir',
            'body' => '',
        ]);

        $invocation = handleNextRequest();

        $response = $this->getInvocationResponse();
        $this->assertEquals(301, $response->statusCode);
        $this->assertEquals('/subdir/', $response->headers->Location);
    }

    /**
     * Requests a path that returns slower than the declared max execution time.
     */
    public function testSlowRequest(): void
    {
        $this->setNextInvocation([
            'requestContext' => [],
            'httpMethod' => 'GET',
            'path' => '/slow',
            'body' => '',
        ]);

        $this->expectOutputString('PHP took longer than 5 seconds to return response');
        $invocation = handleNextRequest();

        $response = $this->getInvocationResponse();
        $this->assertEquals(500, $response->statusCode);
    }

    /**
     * Performs request with a `multiValueHeaders` property.
     */
    public function testMultiValueHeaderRequest(): void
    {
        $this->setNextInvocation([
            'requestContext' => [],
            'httpMethod' => 'GET',
            'path' => '/multi-value-header',
            'multiValueHeaders' => [
                'Test' => [
                    'foo',
                    'bar',
                ],
            ],
            'body' => '',
        ]);

        $invocation = handleNextRequest();

        $response = $this->getInvocationResponse();
        $this->assertEquals('foo', $response->body);
    }

    /**
     * Receive a response with multiple values for the same header key.
     */
    public function testMultiValueHeaderResponse(): void
    {
        $this->setNextInvocation([
            'requestContext' => [],
            'httpMethod' => 'GET',
            'path' => '/multi-value-header',
            'multiValueHeaders' => [],
            'body' => '',
        ]);

        $invocation = handleNextRequest();

        $response = $this->getInvocationResponse();
        $this->assertEquals(['foo', 'bar'], $response->multiValueHeaders->Test);
    }

    /**
     * Performs a request with a standard query string.
     */
    public function testQueryString(): void
    {
        $this->setNextInvocation([
            'requestContext' => [],
            'httpMethod' => 'GET',
            'path' => '/echo',
            'multiValueHeaders' => [],
            'queryStringParameters' => [
                'a' => 'foo',
                'b' => 'bar',
            ],
            'body' => '',
        ]);

        $invocation = handleNextRequest();

        $response = $this->getInvocationResponse();
        $this->assertEquals('{"a":"foo","b":"bar"}', $response->body);
    }

    /**
     * Performs a request with a query string with multiple values against the
     * same key.
     */
    public function testMultiValueQueryString(): void
    {
        $this->setNextInvocation([
            'requestContext' => [],
            'httpMethod' => 'GET',
            'path' => '/echo',
            'multiValueHeaders' => [],
            'multiValueQueryStringParameters' => [
                'a' => [
                    'foo',
                    'bar',
                ],
            ],
            'body' => '',
        ]);

        $invocation = handleNextRequest();

        $response = $this->getInvocationResponse();
        $this->assertEquals('{"a":"bar"}', $response->body);
    }

    /**
     * Performs a request with a PHP-specific array style query string.
     */
    public function testArrayQueryString(): void
    {
        $this->setNextInvocation([
            'requestContext' => [],
            'httpMethod' => 'GET',
            'path' => '/echo',
            'multiValueHeaders' => [],
            'multiValueQueryStringParameters' => [
                'a' => [
                    'foo',
                ],
                'b[]' => [
                    'foo',
                    'bar',
                ],
                'c[a]' => [
                    'foo',
                ],
                'c[b]' => [
                    'bar',
                ],
            ],
            'body' => '',
        ]);

        $invocation = handleNextRequest();

        $response = $this->getInvocationResponse();
        $this->assertEquals(
            '{"a":"foo","b":["foo","bar"],"c":{"a":"foo","b":"bar"}}',
            $response->body
        );
    }

    /**
     * Requests an endpoint which returns an oversized response.
     */
    public function testLargeResponse(): void
    {
        $this->setNextInvocation([
            'requestContext' => [],
            'httpMethod' => 'GET',
            'path' => '/large-response',
            'body' => '',
        ]);

        $this->expectOutputString("Response size is too large for ALB (1000167 bytes)\n");
        $invocation = handleNextRequest();

        $response = $this->getInvocationResponse();
        $this->assertEquals(500, $response->statusCode);
    }

    /**
     * Stops the mock server to ensure the address can be re-used.
     */
    public static function tearDownAfterClass(): void
    {
        self::$server->stop();
    }
}
