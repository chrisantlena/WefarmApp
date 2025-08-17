<?php
// db_config.php - Database configuration

// Database connection details
define('DB_HOST', 'localhost');     // Host name (biasanya localhost)
define('DB_USER', 'root');          // Ganti dengan username database Anda
define('DB_PASSWORD', '');          // Ganti dengan password database Anda
define('DB_NAME', 'wefarm');        // Nama database Anda

// Create connection
function getConnection() {
    $conn = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);
    
    // Check connection
    if ($conn->connect_error) {
        die("Connection failed: " . $conn->connect_error);
    }
    
    // Set character set
    $conn->set_charset("utf8");
    
    return $conn;
}