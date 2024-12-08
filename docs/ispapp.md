# ispapp.rsc Documentation

## Overview
The ispapp.rsc script is the main entry point for the ISPApp agent on MikroTik devices. It initializes the environment, sets up global variables, defines utility functions, and installs other necessary scripts for the ISPApp functionality.

## Script Structure

1. Environment Cleanup
2. Global Variable Initialization
3. Utility Function Definitions
4. Credential Management
5. Agent Setup and Cleanup
6. Script Installation
7. Library Loading
8. Scheduler Setup

## Detailed Breakdown

### 1. Environment Cleanup
- Removes all existing script environment variables to ensure a clean slate.

### 2. Global Variable Initialization
- Sets up global variables for:
  - Host key
  - Domain
  - Client information
  - Ports (Listener, Server, SMTP)
  - Network statistics (txAvg, rxAvg)
  - Bandwidth test server and credentials
  - Library version tracking

### 3. Utility Function Definitions

#### strcaseconv
- Purpose: Converts strings to lowercase or uppercase.
- Usage: `$strcaseconv <input string>`
- Returns: A dictionary with "upper" and "lower" keys containing the converted strings.

#### cleanupagent
- Purpose: Removes old agent setup (scripts, files, schedulers, environment variables).
- Returns: Status message indicating success or failure.

#### generateUniqueId
- Purpose: Generates a unique identifier for the device.
- Behavior: 
  - Attempts to fetch a UUID from the server.
  - If unsuccessful, generates a local unique ID based on the current time.
- Sets the global `login` variable with the generated ID.

### 4. Credential Management
- Checks for existing credentials (ispapp_credentials script).
- Runs the generateUniqueId function if no login is set.

### 5. Agent Setup and Cleanup
- Runs the cleanupagent function to remove any old setup.

### 6. Script Installation
- Downloads and installs the following scripts from the GitHub repository:
  - ispappConfig.rsc
  - ispappInit.rsc
  - ispappUpdate.rsc
  - ispappLibrary.rsc

### 7. Library Loading
- Imports the ispappLibrary.rsc file.
- Runs all scripts named "ispappLibrary".
- Sets a global flag `libLoaded` to true.

### 8. Scheduler Setup
- Creates schedulers for:
  - ispappInit: Runs every 1 minute, starts at startup.
  - ispappUpdate: Runs every 10 seconds, initially disabled.
  - ispappConfig: Runs every 5 minutes, initially disabled.

## Key Functions

### savecredentials
- Not defined in this script, but called. Likely defined in one of the imported libraries.

### refreshToken
- Not defined in this script, but referenced. Likely defined in one of the imported libraries.

## Error Handling
- The script uses try-catch blocks (`:do {...} on-error={...}`) for error handling during script downloads and installations.
- Errors are logged and, in some cases, alternative actions are taken (e.g., local ID generation on server fetch failure).

## Logging
- The script uses the MikroTik logging system to record various stages of the setup process.
- Log levels used: info, error, debug

## Security Considerations
- The script fetches files from a GitHub repository. Ensure the repository URL is correct and secure.
- Credentials are stored and managed, implying the need for secure handling of sensitive information.

## Conclusion
The ispapp.rsc script serves as the bootstrap for the ISPApp agent on MikroTik devices. It sets up the necessary environment, installs required scripts, and initializes the core functionality. Regular maintenance and updates to this script are crucial for the proper functioning of the ISPApp agent.