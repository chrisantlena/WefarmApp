<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

// Database connection
$servername = "localhost";
$username = "root";
$password = "";
$dbname = "wefarm";

try {
    $pdo = new PDO("mysql:host=$servername;dbname=$dbname", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch(PDOException $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Database connection failed: ' . $e->getMessage()]);
    exit();
}

$method = $_SERVER['REQUEST_METHOD'];

switch($method) {
    case 'POST':
        // Create new experience
        $input = json_decode(file_get_contents('php://input'), true);
        
        // Debug: Log received data
        error_log("Received data: " . print_r($input, true));
        
        if (!isset($input['user_id']) || !isset($input['plant_name']) || 
            !isset($input['start_date']) || !isset($input['end_date']) || 
            !isset($input['status']) || !isset($input['experience'])) {
            http_response_code(400);
            echo json_encode([
                'success' => false, 
                'message' => 'Missing required fields',
                'received_data' => $input
            ]);
            exit();
        }
        
        // PERBAIKAN: Pastikan user_id adalah integer
        $userId = intval($input['user_id']);
        
        if ($userId <= 0) {
            http_response_code(400);
            echo json_encode([
                'success' => false, 
                'message' => 'Invalid user_id',
                'received_user_id' => $input['user_id']
            ]);
            exit();
        }
        
        try {
            // Status mapping dari Flutter ke database
            $statusMapping = [
                'Success' => 'success',
                'Failed' => 'failed',
                'Terminated' => 'terminated'
            ];
            
            $dbStatus = isset($statusMapping[$input['status']]) ? 
                       $statusMapping[$input['status']] : 
                       strtolower($input['status']);
            
            $stmt = $pdo->prepare("
                INSERT INTO plant_experiences (
                    user_id,
                    plant_name,
                    start_date,
                    end_date,
                    status,
                    experience,
                    created_at,
                    updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())
            ");
            
            $result = $stmt->execute([
                $userId,
                $input['plant_name'],
                $input['start_date'],
                $input['end_date'],
                $dbStatus,
                $input['experience']
            ]);
            
            if ($result) {
                $experienceId = $pdo->lastInsertId();
                
                http_response_code(201);
                echo json_encode([
                    'success' => true, 
                    'message' => 'Experience created successfully', 
                    'id' => $experienceId
                ]);
            } else {
                http_response_code(500);
                echo json_encode([
                    'success' => false, 
                    'message' => 'Failed to create experience'
                ]);
            }
            
        } catch(PDOException $e) {
            http_response_code(500);
            echo json_encode([
                'success' => false, 
                'message' => 'Database error: ' . $e->getMessage()
            ]);
        }
        break;

    case 'GET':
        try {
            $query = "
                SELECT 
                    pe.*,
                    u.username as author
                FROM plant_experiences pe
                LEFT JOIN users u ON pe.user_id = u.id
                WHERE 1=1
            ";
            
            $params = [];
            
            // PERBAIKAN: Handling user_id untuk My Experiences
            if (isset($_GET['user_id']) && !empty($_GET['user_id'])) {
                $getUserId = intval($_GET['user_id']);
                
                if ($getUserId > 0) {
                    $query .= " AND pe.user_id = ?";
                    $params[] = $getUserId;
                    
                    // Debug log
                    error_log("Filtering by user_id: " . $getUserId);
                }
            }
            
            // PERBAIKAN: Parameter community untuk mengambil semua data
            if (isset($_GET['community']) && $_GET['community'] == '1') {
                // Untuk community, tidak ada filter user_id khusus
                // Tapi kita bisa tambahkan logic lain jika diperlukan
                error_log("Fetching community experiences");
            }
            
            // Filter by plant name
            if (isset($_GET['plant']) && !empty($_GET['plant'])) {
                $query .= " AND pe.plant_name = ?";
                $params[] = $_GET['plant'];
            }
            
            // Filter by status
            if (isset($_GET['status']) && !empty($_GET['status'])) {
                $statusFilter = $_GET['status'];
                $statuses = explode(',', $statusFilter);
                $placeholders = implode(',', array_fill(0, count($statuses), '?'));
                $query .= " AND pe.status IN ($placeholders)";
                $params = array_merge($params, $statuses);
            }
            
            $query .= " ORDER BY pe.created_at DESC";
            
            // Debug log
            error_log("Final query: " . $query);
            error_log("Parameters: " . print_r($params, true));
            
            $stmt = $pdo->prepare($query);
            $stmt->execute($params);
            $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
            
            // Debug log
            error_log("Results count: " . count($results));
            
            // Format hasil untuk konsistensi dengan Flutter
            $formattedResults = array_map(function($exp) {
                return [
                    'id' => $exp['id'],
                    'plant_name' => $exp['plant_name'],
                    'author' => $exp['author'] ?? 'Unknown',
                    'experience' => $exp['experience'],
                    'status' => $exp['status'],
                    'start_date' => $exp['start_date'],
                    'end_date' => $exp['end_date'],
                    'created_at' => $exp['created_at'],
                    'updated_at' => $exp['updated_at'],
                    'user_id' => $exp['user_id'] // Tambahkan user_id untuk debugging
                ];
            }, $results);
            
            echo json_encode(['success' => true, 'data' => $formattedResults]);
            
        } catch(PDOException $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
        }
        break;

    case 'PUT':
        // Update experience
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (!isset($input['id'])) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Experience ID is required']);
            exit();
        }
        
        try {
            $updateFields = [];
            $params = [];
            
            if (isset($input['plant_name'])) {
                $updateFields[] = 'plant_name = ?';
                $params[] = $input['plant_name'];
            }
            
            if (isset($input['start_date'])) {
                $updateFields[] = 'start_date = ?';
                $params[] = $input['start_date'];
            }
            
            if (isset($input['end_date'])) {
                $updateFields[] = 'end_date = ?';
                $params[] = $input['end_date'];
            }
            
            if (isset($input['status'])) {
                $statusMapping = [
                    'Success' => 'success',
                    'Failed' => 'failed',
                    'Terminated' => 'terminated'
                ];
                
                $dbStatus = isset($statusMapping[$input['status']]) ? 
                           $statusMapping[$input['status']] : 
                           strtolower($input['status']);
                
                $updateFields[] = 'status = ?';
                $params[] = $dbStatus;
            }
            
            if (isset($input['experience'])) {
                $updateFields[] = 'experience = ?';
                $params[] = $input['experience'];
            }
            
            if (empty($updateFields)) {
                http_response_code(400);
                echo json_encode(['success' => false, 'message' => 'No fields to update']);
                exit();
            }
            
            $updateFields[] = 'updated_at = NOW()';
            $params[] = $input['id'];
            
            $query = "UPDATE plant_experiences SET " . implode(', ', $updateFields) . " WHERE id = ?";
            
            $stmt = $pdo->prepare($query);
            $result = $stmt->execute($params);
            
            if ($result && $stmt->rowCount() > 0) {
                echo json_encode(['success' => true, 'message' => 'Experience updated successfully']);
            } else {
                echo json_encode(['success' => false, 'message' => 'Experience not found or no changes made']);
            }
            
        } catch(PDOException $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
        }
        break;

    case 'DELETE':
        // Delete experience
        $input = json_decode(file_get_contents('php://input'), true);
        
        if (!isset($input['id'])) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Experience ID is required']);
            exit();
        }
        
        try {
            $stmt = $pdo->prepare("DELETE FROM plant_experiences WHERE id = ?");
            $result = $stmt->execute([$input['id']]);
            
            if ($result && $stmt->rowCount() > 0) {
                echo json_encode(['success' => true, 'message' => 'Experience deleted successfully']);
            } else {
                echo json_encode(['success' => false, 'message' => 'Experience not found']);
            }
            
        } catch(PDOException $e) {
            http_response_code(500);
            echo json_encode(['success' => false, 'message' => 'Database error: ' . $e->getMessage()]);
        }
        break;

    default:
        http_response_code(405);
        echo json_encode(['success' => false, 'message' => 'Method not allowed']);
        break;
}
?>