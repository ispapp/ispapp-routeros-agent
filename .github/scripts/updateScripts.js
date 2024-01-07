const fs = require('fs');
const path = require('path');

const scriptsFolder = 'raw';
const outputFileName = 'ispappLibrary.rsc';
const prefixregex = /ispappLibrary/;

const getAllFiles = (dir) => {
  const files = fs.readdirSync(dir);
  const librariesresult = [];
  const othersresult = [];

  files.forEach((file) => {
    const filePath = path.join(dir, file);
    const stat = fs.statSync(filePath);

    if (stat.isDirectory()) {
      librariesresult.push(...getAllFiles(filePath));
    } else {
      if (prefixregex.test(file)) {
        librariesresult.push(filePath);
      } else {
        othersresult.push(filePath)
      }
    }
  });

  return {libraries:librariesresult, others:othersresult};
};

const getFormattedScript = (scriptContent=[]) => {
  return scriptContent
    .split('\n')
    .map((line, i) => (i <= (scriptContent.split('\n').length - 1)) ? `\n${line.replace(/\\/g, '\\\\').replace(/\$/g, '\\$').replace(/"/g, '\\"')}\r`: line)
    .join('');
};

const processlibraryScripts = (scripts) => {
  const uniqueCommands = new Set();

  scripts.forEach((scriptPath) => {
    const scriptContent = fs.readFileSync(scriptPath, 'utf-8');
    const formattedScript = getFormattedScript(scriptContent);
    const scriptName = path.basename(scriptPath, path.extname(scriptPath));
    
    const finalCommand = `\n add dont-require-permissions=yes name=${scriptName} owner=admin policy=\
ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="${formattedScript}"`;
    uniqueCommands.add(finalCommand);
  });

  return Array.from(uniqueCommands).join('\n');
};
const processotherScripts = (scripts) => {
  scripts.forEach((scriptPath) => {
    if (path.extname(scriptPath) == '.rsc') {
    const scriptContent = fs.readFileSync(scriptPath, 'utf-8');
    const formattedScript = getFormattedScript(scriptContent);
    const scriptName = path.basename(scriptPath, path.extname(scriptPath));
    const scriptFileName = `${path.basename(scriptPath, path.extname(scriptPath))}${path.extname(scriptPath)}`;
    const finalCommand = `/system script add dont-require-permissions=yes name=${scriptName} owner=admin policy=\
ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="${formattedScript}"`;
    const outputFilePath = path.join(__dirname, '../../', scriptFileName);
    console.log(`\n ${outputFilePath} ✅`);
    fs.writeFileSync(outputFilePath, finalCommand);
    }
  });
};
const scriptsFolderFullPath = path.join(__dirname, '../../', scriptsFolder);
const outputFilePath = path.join(__dirname, '../../', outputFileName);

const allFiles = getAllFiles(scriptsFolderFullPath);
const ispappLibrary = processlibraryScripts(allFiles.libraries);
fs.writeFileSync(outputFilePath, `/system script ${ispappLibrary}`);
console.log(`
############# job done ########
${allFiles.libraries.map(file => `${file} ✅`).join("\n")} ✅
      ⬇
${outputFilePath} ✅
###############################
`);
processotherScripts(allFiles.others);

