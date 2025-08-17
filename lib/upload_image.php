<?php
// SUPER SIMPLE upload_image.php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST');
header('Access-Control-Allow-Headers: Content-Type');

require_once 'db_config.php';

// Cek basic requirements
if (!isset($_POST['user_id']) || !isset($_FILES['profile_image'])) {
    echo json_encode(['success' => false, 'message' => 'Missing data']);
    exit;
}

$user_id = $_POST['user_id'];
$file = $_FILES['profile_image'];

// Cek file upload berhasil
if ($file['error'] !== UPLOAD_ERR_OK) {
    echo json_encode(['success' => false, 'message' => 'Upload error: ' . $file['error']]);
    exit;
}

try {
    // Buat folder upload kalo belum ada
    $upload_dir = dirname(__FILE__) . '/../uploads/profiles/';
    if (!is_dir($upload_dir)) {
        mkdir($upload_dir, 0777, true);
    }

    // Hapus foto lama user ini
    $old_files = glob($upload_dir . $user_id . '_*');
    foreach ($old_files as $old_file) {
        unlink($old_file);
    }

    // Nama file baru
    $extension = pathinfo($file['name'], PATHINFO_EXTENSION);
    $new_filename = $user_id . '_' . time() . '.' . $extension;
    $target_path = $upload_dir . $new_filename;

    // Pindahkan file
    if (!move_uploaded_file($file['tmp_name'], $target_path)) {
        throw new Exception('Failed to move file');
    }

    // Path untuk database (relatif)
    $db_path = 'uploads/profiles/' . $new_filename;
    
    // Path untuk response (full URL)
    $full_url = 'http://192.168.56.1/wefarm/' . $db_path;

    // Update database
    $conn = getConnection();
    $stmt = $conn->prepare("UPDATE users SET photo_url = ? WHERE id = ?");
    $stmt->bind_param("si", $db_path, $user_id);
    
    if (!$stmt->execute()) {
        throw new Exception('Database update failed');
    }

    $stmt->close();
    $conn->close();

    // Response sukses
    echo json_encode([
        'success' => true,
        'message' => 'Upload successful',
        'photoUrl' => $full_url,
        'filename' => $new_filename
    ]);

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>