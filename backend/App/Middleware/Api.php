<?php

namespace App\Middleware;

use \Response;
use \Valid;

class Api {
  public function index() {
    Response::setType(\Response::TYPE_API);

    Valid::setIfError(static function(string $error, $code = null) {
      error($error, $code ?? 400);
    });
  }
}
