<?php
// get_user.php - FIXED VERSION sesuai struktur database

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// ✅ INCLUDE db_config yang sudah ada
require_once 'db_config.php';

function sanitize($data) {
    $data = trim($data);
    $data = stripslashes($data);
    $data = htmlspecialchars($data);
    return $data;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid request method. Only POST requests are allowed.'
    ]);
    exit;
}

$json_data = file_get_contents('php://input');
$data = json_decode($json_data, true);

if (json_last_error() !== JSON_ERROR_NONE) {
    echo json_encode([
        'success' => false,
        'message' => 'Invalid JSON data.'
    ]);
    exit;
}

if (!isset($data['user_id']) || empty($data['user_id'])) {
    echo json_encode([
        'success' => false,
        'message' => 'User ID is required.'
    ]);
    exit;
}

$user_id = sanitize($data['user_id']);

try {
    // ✅ GUNAKAN getConnection() dari db_config
    $conn = getConnection();
    
    // ✅ FIXED: Sesuaikan dengan struktur database yang benar
    $stmt = $conn->prepare("SELECT id, username, email, phone, address, photo_url FROM users WHERE id = ?");
    $stmt->bind_param("i", $user_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        echo json_encode([
            'success' => false,
            'message' => 'User not found.'
        ]);
        $stmt->close();
        $conn->close();
        exit;
    }
    
    $user = $result->fetch_assoc();
    
    // ✅ FIXED: Response mapping sesuai yang diharapkan Flutter
    $response_user = [
        'id' => $user['id'],
        'name' => $user['username'],        // database 'username' -> Flutter 'name'
        'username' => $user['username'],    // Keep original
        'email' => $user['email'],
        'phone' => $user['phone'],
        'address' => $user['address'],
        'photo_url' => $user['photo_url'],
        'photoUrl' => $user['photo_url'],   // Alternative naming
        'profile_image' => $user['photo_url'] // Alternative naming
    ];
    
    echo json_encode([
        'success' => true,
        'message' => 'User data retrieved successfully.',
        'user' => $response_user
    ]);
    
    $stmt->close();
    $conn->close();
    
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}
?>