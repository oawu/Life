<?php

namespace App\Controller\Api;

use \Orm\Core\Connection;
use \Request\Payload;
use \Valid;

class Test {
    public function reset() {
        if (ENVIRONMENT === 'Production') {
            error('Not available in production', 403);
        }

        $tables = [
            'Settlement',
            'RecurringExpense',
            'Expense',
            'Category',
            'LedgerMember',
            'Ledger',
            'User',
        ];

        $conn = Connection::instance();
        $conn->runQuery("SET FOREIGN_KEY_CHECKS = 0");

        foreach ($tables as $table) {
            $conn->runQuery("TRUNCATE TABLE `{$table}`");
        }

        $conn->runQuery("SET FOREIGN_KEY_CHECKS = 1");

        return ['success' => true];
    }

    public function query() {
        if (ENVIRONMENT === 'Production') {
            error('Not available in production', 403);
        }

        list(
            'sql' => $sql,
        ) = Valid::check(Payload::getJson(), [
            'sql' => Valid::string('SQL')->min(1)->max(2000),
        ]);

        // 只允許單一 SELECT
        $trimmed = ltrim($sql);
        if (stripos($trimmed, 'SELECT') !== 0) {
            error('Only SELECT queries allowed', 400);
        }
        if (strpos($sql, ';') !== false) {
            error('Multiple statements not allowed', 400);
        }

        $conn = Connection::instance();
        $stmt = null;
        $exception = $conn->runQuery($sql, [], $stmt);

        if ($exception) {
            error($exception->getMessage(), 400);
        }

        $rows = $stmt->fetchAll(\PDO::FETCH_ASSOC);

        return ['rows' => $rows];
    }
}
