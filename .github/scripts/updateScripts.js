const fs = require('fs');
const path = require('path');

const scriptsFolder = 'raw';
const outputFileName = 'ispappLibrary.rsc';
const prefix = 'ispappLibrary';

const getAllFiles = (dir) => {
  const files = fs.readdirSync(dir);
  const result = [];

  files.forEach((file) => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory()) {
      result.push(...getAllFiles(filePath));
    } else {
      result.push(filePath);
    }
  });

  return result;
};

const getFormattedScript = (scriptContent) => {
  return scriptContent
    .split('\n')
    .map((line) => `\\r\\n${line.trim()}`)
    .join('');
};

const processScripts = (scripts) => {
  const uniqueCommands = new Set();

  scripts.forEach((scriptPath) => {
    if (scriptPath.startsWith(prefix)) {
      const scriptContent = fs.readFileSync(scriptPath, 'utf-8');
      const formattedScript = getFormattedScript(scriptContent);
      const finalCommand = `/system script add dont-require-permissions=yes name=${path.basename(scriptPath, path.extname(scriptPath))} owner=admin policy=\\
      ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="${formattedScript}"`;

      uniqueCommands.add(finalCommand);
    }
  });

  return Array.from(uniqueCommands).join('\\r\\n');
};

const scriptsFolderFullPath = path.join(__dirname, '../../', scriptsFolder);
const outputFilePath = path.join(__dirname, '../../', outputFileName);

const allFiles = getAllFiles(scriptsFolderFullPath);
const finalCommands = processScripts(allFiles);

fs.writeFileSync(outputFilePath, finalCommands);
