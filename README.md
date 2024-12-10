# RAF Student Registry - GNO Smart Contract

A blockchain-based student registry system for RAF (Računarski Fakultet) built on GNO Chain. This smart contract implements a non-transferable NFT-based student identity and record management system.

## Educational Purpose

This project was developed as an educational exercise to demonstrate blockchain concepts and smart contract development on the GNO Chain. While functional, it serves as a proof of concept and would need additional features and security measures for real-world deployment.

**Note:** This project is not deployed to any network as it serves purely educational purposes. The code is meant to demonstrate smart contract development concepts and patterns.

## Overview

The RAF Student Registry is a decentralized application that manages student records using non-transferable NFTs (GRC721). Each student receives a unique NFT that represents their academic identity and contains their educational information.

### Key Features

- **Non-transferable Student NFTs**: Each student receives a unique, non-transferable NFT representing their academic identity
- **Academic Record Management**: Track student information, academic status, and graduation
- **Department Management**: Handle department transfers and academic progression
- **Administrative Controls**: Multi-admin system for managing student records
- **Academic Status Tracking**: Monitor student status including probation and graduation

## Smart Contract Structure

The system consists of two main components:

1. `raf.gno`: Public interface for interacting with the registry
2. `registry.gno`: Core implementation of the student registry system

