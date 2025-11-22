# VoteSphere DAO

**On-chain tokenless membership voting system for Stacks/Clarity**

## Overview

VoteSphere is a simple DAO contract enabling decentralized governance without tokens. Membership is managed by an admin, and members can vote on proposals. Each member gets one vote per proposal, and voting windows are enforced by block height.

## Features

- **Admin controls**: Add/remove members, create/close proposals, change admin
- **Membership voting**: Each member gets one vote per proposal
- **Voting windows**: Proposals have start and end block heights
- **Double-voting prevention**: Members can only vote once per proposal
- **Event logging**: Key actions emit events for off-chain indexing

## Contract Functions

### Admin Functions

- `change-admin(new-admin)`  
  Change the contract admin

- `add-member(user)`  
  Add a new member

- `remove-member(user)`  
  Remove a member

- `create-proposal(title, description, start-block, end-block)`  
  Create a new proposal

- `close-proposal(proposal-id)`  
  Close a proposal early

### Member Functions

- `cast-vote(proposal-id, support)`  
  Cast a vote (support = true for, false against)

### Read-Only Functions

- `get-proposal(proposal-id)`  
  Get proposal details

- `get-proposal-count()`  
  Get total number of proposals

- `check-member(addr)`  
  Check if an address is a member

- `has-voted-on(proposal-id, voter)`  
  Check if a voter has voted on a proposal

- `proposal-result(proposal-id)`  
  Get a summary of proposal results

## Data Structures

- **Admin**: Principal address with admin rights
- **Members**: Map of principal addresses to membership status
- **Proposals**: Map of proposal IDs to proposal details
- **Has-voted**: Map tracking if a member has voted on a proposal

## Events

Events are emitted using the `print` function for off-chain indexing.  
Examples:
- `member-added`
- `member-removed`
- `proposal-created`
- `proposal-closed`
- `vote-cast`
- `admin-changed`

## Usage

Deploy the contract using [Clarinet](https://docs.stacks.co/docs/clarinet/overview/) or your preferred Stacks tool.  
Admin is set to the deploying principal.  
Use the public functions to manage members and proposals, and allow members to vote.

