<?php

if (file_exists('/opt/vendor/autoload.php')) {
    require '/opt/vendor/autoload.php';
} else {
    require __DIR__ . '/../../../vendor/autoload.php';
}

$app = new Slim\App();

$app->get('/', function ($request, $response) {
    return $response->getBody()->write('Home');
});

$app->post('/', function ($request, $response) {
    $post = $request->getParsedBody();
    $string = $post['foo'] . $post['bar'];
    return $response->getBody()->write($string);
});

$app->get('/foo/{bar}/baz', function ($request, $response, array $args) {
    ['bar' => $bar] = $args;
    return $response->getBody()->write("foo/${bar}/baz");
});

$app->get('/slow', function ($request, $response) {
    sleep(10);
});

$app->get('/multi-value-header', function ($request, $response) {
    $body = $response->getBody();
    $body->write($request->getHeaderLine('Test'));
    return $response
        ->withAddedHeader('Test', 'foo')
        ->withAddedHeader('Test', 'bar');
});

$app->get('/echo', function ($request, $response) {
    return $response->withJson($request->getQueryParams());
});

$app->get('/large-response', function ($request, $response) {
    $body = $response->getBody();
    while ($body->getSize() < 1000000) {
        $body->write(' ');
    }
    return $response;
});

$app->run();
