<?php

// Allow infinite execution time
set_time_limit(0);

define('UPLOAD_FOLDER',	'/var/www-upload/');

    
handleRequest();
    
function handleRequest()
{
    $method = $_SERVER['REQUEST_METHOD'];

    switch ($method)
    {
        case 'GET':
        {
            processGetRequest();
            break;
        }
            
        case 'POST':
        {
            processPostRequest();
            break;
        }
            
        default:
        {
            processUnknownRequest();
            break;
        }
    }
}
    
function processGetRequest()
{
    $fileName = queryStringArg('fileName');
    if (!$fileName)
    {
        header('Content-type: application/json');
        $obj = new stdClass();
        $obj->errorCode = -1;
        $obj->errorMessage = 'file name required';
        echo json_encode($obj);
        die();
    }
    
    $path = UPLOAD_FOLDER . $fileName;
    
    if (!file_exists($path))
    {
        header('Content-type: application/json');
        $obj = new stdClass();
        $obj->errorCode = -1;
        $obj->errorMessage = 'file does not exist';
        echo json_encode($obj);
        die();
    }
    else
    {
        header('Content-type:text/plain; charset=utf-8');
        header('Content-Disposition: attachment; filename=' . $fileName);
        $in = fopen($path, 'rb');
        $out = fopen('php://output', 'wb');
        pipeFile($in, $out);
    }
}
    
function processPostRequest()
{
    header('Content-type: application/json');
    
    $fileName = queryStringArg('fileName');
    if (!$fileName)
    {
        $obj = new stdClass();
        $obj->errorCode = -1;
        $obj->errorMessage = 'file name required';
        echo json_encode($obj);
        die();
    }
    
    $path = UPLOAD_FOLDER . $fileName;
    
    $in = fopen('php://input', 'rb');
    $out = fopen($path, 'wb');
    pipeFile($in, $out);
    
    $obj = new stdClass();
    $obj->returnCode = 0;
    $obj->fileSize = filesize($path);
    $obj->fileHash = md5_file($path);
    $obj->fileName = $fileName;
    
    echo json_encode($obj);
}
 
function processUnknownRequest()
{
    header('Content-type: application/json');

    $obj = new stdClass();
    $obj->error = 'Unexpected HTTP request verb: ' . $_SERVER['REQUEST_METHOD'];
    echo json_encode($obj);
}
    
function pipeFile($in, $out)
{
    $size = 0;
    while (!feof($in))
    {
        $chunk = fread($in, 8192);
        if ($chunk === FALSE)
            break;
        
        $size += fwrite($out, $chunk);
    }
}
    
function queryStringArg($argName, $default = NULL)
{
    $array = $_GET;
    if ($array && is_array($array) && $argName && isset($array[$argName]))
    {
        return $array[$argName];
    }
    
    return $default;
}
 
?>