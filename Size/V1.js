
const fs = require('fs');
const path = require('path');

// Function to get the size of a directory
function getDirectorySize(directoryPath) {
    let totalSize = 0;
    try {
        const files = fs.readdirSync(directoryPath);
        files.forEach(file => {
            const filePath = path.join(directoryPath, file);
            const stats = fs.statSync(filePath);
            if (stats.isDirectory()) {
                totalSize += getDirectorySize(filePath); // Recursive for subdirectories
            } else {
                totalSize += stats.size;
            }
        });
    } catch (error) {
        console.error(`Error reading directory: ${directoryPath}`, error);
    }
    return totalSize;
}

// Function to get largest files on C drive
function getLargestFiles(directoryPath, topN = 20) {
    let fileSizes = [];
    function scanDirectory(directory) {
        const files = fs.readdirSync(directory);
        files.forEach(file => {
            const filePath = path.join(directory, file);
            const stats = fs.statSync(filePath);
            if (stats.isFile()) {
                fileSizes.push({ filePath, size: stats.size });
            } else if (stats.isDirectory()) {
                scanDirectory(filePath); // Recursive for nested files
            }
        });
    }
    scanDirectory(directoryPath);
    return fileSizes
        .sort((a, b) => b.size - a.size)
        .slice(0, topN)
        .map(file => `${file.filePath} - ${(file.size / (1024 * 1024 * 1024)).toFixed(2)} GB`);
}

// Function to get top-level directory sizes with one level of subdirectory sizes
function getLayeredDirectorySizes(directoryPath) {
    let topLevelDirs = [];
    try {
        const directories = fs.readdirSync(directoryPath);
        directories.forEach(dir => {
            const dirPath = path.join(directoryPath, dir);
            const stats = fs.statSync(dirPath);
            if (stats.isDirectory()) {
                let subDirSizes = [];
                const subDirs = fs.readdirSync(dirPath);
                let totalSize = 0;
                subDirs.forEach(subDir => {
                    const subDirPath = path.join(dirPath, subDir);
                    const subStats = fs.statSync(subDirPath);
                    let subDirSize = 0;
                    if (subStats.isDirectory()) {
                        subDirSize = getDirectorySize(subDirPath);
                        subDirSizes.push(`${subDir} = ${(subDirSize / (1024 * 1024 * 1024)).toFixed(2)} GB`);
                    }
                    totalSize += subDirSize;
                });
                topLevelDirs.push(`${dir} = ${(totalSize / (1024 * 1024 * 1024)).toFixed(2)} GB`);
                topLevelDirs = topLevelDirs.concat(subDirSizes);
            }
        });
    } catch (error) {
        console.error(`Error reading top-level directories: ${directoryPath}`, error);
    }
    return topLevelDirs;
}

// Define main function to run and format results
function main() {
    const largestFiles = getLargestFiles('C:\\', 20);
    const layeredDirSizes = getLayeredDirectorySizes('C:\\');

    // Format the output for NinjaRMM (here we log it; replace this part with actual integration code)
    console.log("Top 20 Largest Files:");
    console.log(largestFiles.join("\n"));
    console.log("\nLayered Directory Sizes:");
    console.log(layeredDirSizes.join("\n"));

    // Placeholder for NinjaRMM integration: replace console logs with custom field population code
    // e.g., Ninja-Property-Set customFieldName "Top Largest Files: \n" + largestFiles.join("\n")
    // e.g., Ninja-Property-Set customFieldName "Layered Directory Sizes: \n" + layeredDirSizes.join("\n")
}

main();

