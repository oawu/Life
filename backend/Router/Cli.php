<?php

Router::cli()->func(fn() => 'Hello!');

Router::cli('test/worker')->controller(\App\Controller\Cli\Worker::class . '@test')->title('測試 Worker');
Router::cli('recurring/trigger')->controller(\App\Controller\Cli\Recurring::class . '@trigger')->title('觸發固定開銷排程');
