const { exec } = require('child_process');
const fs = require('fs').promises;
const path = require('path');
const Jimp = require('jimp');
const os = require('os');

async function isWSL() {
  try {
    const release = await fs.readFile('/proc/version', 'utf8');
    return release.toLowerCase().includes('microsoft');
  } catch {
    return false;
  }
}

async function getClipboardImage() {
  const platform = os.platform();
  const isWSLEnv = await isWSL();
  
  if (platform === 'win32' || platform === 'linux') {
    let tempFile;
    
    if (isWSLEnv) {
      // WSL: Use Windows temp directory
      const winTemp = '/mnt/c/Windows/Temp';
      tempFile = path.join(winTemp, `clipboard-${Date.now()}.png`);
    } else {
      tempFile = path.join(os.tmpdir(), `clipboard-${Date.now()}.png`);
    }
    
    return new Promise((resolve, reject) => {
      let command;
      
      if (platform === 'win32') {
        command = `powershell -command "Add-Type -AssemblyName System.Windows.Forms; $img = [System.Windows.Forms.Clipboard]::GetImage(); if ($img -ne $null) { $img.Save('${tempFile}', [System.Drawing.Imaging.ImageFormat]::Png); '${tempFile}' } else { 'no-image' }"`;
      } else if (isWSLEnv) {
        // WSL: Use PowerShell from Windows to access the clipboard
        const winPath = tempFile.replace('/mnt/c/', 'C:\\').replace(/\//g, '\\');
        command = `powershell.exe -command "Add-Type -AssemblyName System.Windows.Forms; \\$img = [System.Windows.Forms.Clipboard]::GetImage(); if (\\$img -ne \\$null) { \\$img.Save('${winPath}', [System.Drawing.Imaging.ImageFormat]::Png); '${tempFile}' } else { Write-Host 'no-image' }"`;
      } else {
        command = `xclip -selection clipboard -t image/png -o > "${tempFile}" 2>/dev/null && echo "${tempFile}" || echo "no-image"`;
      }
      
      exec(command, async (error, stdout, stderr) => {
        const output = stdout.trim();
        if (error || output === 'no-image' || output.includes('no-image')) {
          try {
            await fs.unlink(tempFile).catch(() => {});
          } catch (e) {}
          resolve(null);
        } else {
          // Verify file exists before returning
          try {
            await fs.access(tempFile);
            resolve(tempFile);
          } catch {
            resolve(null);
          }
        }
      });
    });
  } else if (platform === 'darwin') {
    const tempFile = path.join(os.tmpdir(), `clipboard-${Date.now()}.png`);
    
    return new Promise((resolve, reject) => {
      exec(`osascript -e 'set png_data to the clipboard as «class PNGf»' -e 'set the_file to open for access POSIX file "${tempFile}" with write permission' -e 'write png_data to the_file' -e 'close access the_file' 2>/dev/null && echo "${tempFile}" || echo "no-image"`, async (error, stdout, stderr) => {
        if (error || stdout.trim() === 'no-image') {
          try {
            await fs.unlink(tempFile).catch(() => {});
          } catch (e) {}
          resolve(null);
        } else {
          resolve(tempFile);
        }
      });
    });
  } else {
    throw new Error('Unsupported platform');
  }
}

async function saveClipboardImage(outputPath, format = 'png') {
  const tempFile = await getClipboardImage();
  
  if (!tempFile) {
    return null;
  }
  
  try {
    const image = await Jimp.read(tempFile);
    
    const ext = path.extname(outputPath).toLowerCase().slice(1);
    const outputFormat = ext || format.toLowerCase();
    
    if (!['png', 'jpg', 'jpeg', 'bmp'].includes(outputFormat)) {
      throw new Error('Unsupported format. Use png, jpg, jpeg, or bmp');
    }
    
    const finalPath = ext ? outputPath : `${outputPath}.${outputFormat}`;
    
    if (outputFormat === 'jpg' || outputFormat === 'jpeg') {
      await image.quality(90).writeAsync(finalPath);
    } else {
      await image.writeAsync(finalPath);
    }
    
    await fs.unlink(tempFile).catch(() => {});
    
    return finalPath;
  } catch (error) {
    await fs.unlink(tempFile).catch(() => {});
    throw error;
  }
}

module.exports = {
  saveClipboardImage,
  getClipboardImage
};