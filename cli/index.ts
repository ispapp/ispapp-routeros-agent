import path from "path";

const getFormattedScript = (scriptContent: string) => {
    return scriptContent
        .split('\n')
        .map((line: string, i: number) => (i <= (scriptContent.split('\n').length - 1)) ? `\n${line.replace(/\\/g, '\\\\').replace(/\$/g, '\\$').replace(/"/g, '\\"')}\r` : line)
        .join('');
};

const processLibraryScripts = async (scriptPath: any) => {
    let _path = path.join(__dirname, scriptPath);
    try {
        const scriptContent = await Bun.file(_path).text();
        const formattedScript = getFormattedScript(scriptContent);
        const scriptName = path.basename(_path, path.extname(_path));
        const outputFilePath = path.join(path.dirname(_path), "formatted-" + scriptName + path.extname(_path));
        const finalCommand = `/system script add dont-require-permissions=yes name=${scriptName} owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="${formattedScript}"`;
        await Bun.write(Bun.file(outputFilePath), finalCommand);
        console.log(`\n ${outputFilePath} ✅`);
    } catch (error) {
        return console.error("error: <", JSON.stringify(error), ">");
    }
};
const displayHelp = () => {
    console.log("Usage: exec <filename.rsc>");
    console.log("Description: This script processes a library script and generates a formatted version of it.");
    console.log("Arguments:");
    console.log("  <filename.rsc>: Path to the library script file to be processed.");
};
async function main() {
    if (process.argv.length !== 3) {
        displayHelp();
        return;
    }
    let filepath = process.argv[2];
    await processLibraryScripts(filepath);
}

await main();
