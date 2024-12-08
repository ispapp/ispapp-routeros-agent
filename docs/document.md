# ISPApp MikroTik Agent Script

## Overview
The ISPApp agent for MikroTik devices consists of several interconnected scripts that work together to provide a comprehensive management and monitoring solution. This document outlines how these scripts interact and depend on each other.

## Script Hierarchy and Interactions

1. ispapp.rsc (Main Entry Point)
2. ispappConfig.rsc
3. ispappInit.rsc
4. ispappUpdate.rsc
5. ispappLibrary.rsc (and versions V0 to V4)

### 1. ispapp.rsc (Main Entry Point)

- **Role**: Bootstraps the entire ISPApp agent setup.
- **Interactions**:
  - Initializes global variables used by other scripts.
  - Downloads and installs other scripts (Config, Init, Update, Library).
  - Sets up schedulers for Init, Update, and Config scripts.
  - Runs the Init script after setup.

### 2. ispappConfig.rsc

- **Role**: Manages device configuration and synchronization.
- **Interactions**:
  - Called periodically by a scheduler set up in ispapp.rsc.
  - Uses global variables set by ispapp.rsc.
  - Calls functions from ispappLibrary scripts (e.g., WirelessInterfacesConfigSync).
  - Interacts with ispappInit.rsc indirectly through scheduler management.

### 3. ispappInit.rsc

- **Role**: Handles authentication and initialization of the agent.
- **Interactions**:
  - Called by a scheduler set up in ispapp.rsc.
  - Uses global variables set by ispapp.rsc.
  - Loads ispappLibrary scripts if not already loaded.
  - Manages schedulers for Config and Update scripts based on authentication status.
  - Interacts with the ISPApp server for authentication.

### 4. ispappUpdate.rsc

- **Role**: Manages updates and executes commands from the server.
- **Interactions**:
  - Called periodically by a scheduler set up in ispapp.rsc.
  - Uses functions from ispappLibrary scripts (e.g., sendUpdate, submitCmds).
  - Can modify scheduler intervals for itself and ispappConfig.rsc.
  - Interacts with the ISPApp server to receive updates and commands.

### 5. ispappLibrary.rsc (and versions V0 to V4)

- **Role**: Provides utility functions and core functionality used by other scripts.
- **Interactions**:
  - Loaded by ispappInit.rsc if not already present.
  - Provides functions used by Config, Init, and Update scripts.
  - Defines global variables and functions used across all scripts.

## Data Flow

1. **Authentication Flow**:
   ispapp.rsc -> ispappInit.rsc -> ISPApp Server -> ispappLibrary functions

2. **Configuration Sync Flow**:
   ispapp.rsc -> ispappConfig.rsc -> ispappLibrary functions -> ISPApp Server

3. **Update Flow**:
   ispapp.rsc -> ispappUpdate.rsc -> ispappLibrary functions -> ISPApp Server

## Dependency Chain

1. ispapp.rsc (depends on all other scripts)
2. ispappConfig.rsc (depends on Library scripts)
3. ispappInit.rsc (depends on Library scripts)
4. ispappUpdate.rsc (depends on Library scripts)
5. ispappLibrary scripts (no dependencies, but used by all others)

## Scheduler Interactions

- ispapp.rsc sets up initial schedulers for all main scripts.
- ispappInit.rsc can enable/disable Config and Update schedulers based on authentication status.
- ispappUpdate.rsc can modify its own scheduler interval and that of ispappConfig.rsc based on server instructions.

## Error Handling and Recovery

- Each script implements its own error handling.
- ispappInit.rsc plays a crucial role in recovering from authentication failures.
- ispappUpdate.rsc can trigger system-wide actions like reboots or firmware updates.

## Security Considerations

- Authentication tokens are managed primarily by ispappInit.rsc.
- All scripts that communicate with the server rely on these tokens.
- Command execution in ispappUpdate.rsc requires careful security validation.

## Conclusion

The ISPApp agent for MikroTik devices is a well-structured system with clear separation of concerns. The main entry point (ispapp.rsc) sets up the environment, while specialized scripts handle configuration, initialization, and updates. The library scripts provide the core functionality used across the system. This modular approach allows for easier maintenance and updates to specific components without affecting the entire system.