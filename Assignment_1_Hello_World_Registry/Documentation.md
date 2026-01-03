# Assignment 1: Hello World Registry

## Student Information
- Name: Rhema Joseph
- Date: January 3, 2026

## Contract Overview
This contract implements a simple message registry where users can store, retrieve, update, and delete personalized greeting messages. Each user is identified by their principal address and can only manage their own message.

## Assumptions Made
- Once a message is set, it can be freely updated by the same user
- Deleted messages cannot be recovered
- Empty messages are not allowed (must have at least 1 character)
- Messages are limited to 500 characters maximum
- Any user can read any other user's message (public registry)
- Deleting a non-existent message does not produce an error

## Design Decisions and Tradeoffs

### Decision 1: Using `map-set` Instead of `map-insert`
- **What I chose:** Used `map-set` for storing messages
- **Why:** Allows users to update their messages without needing a separate update function. This makes the contract simpler and more user-friendly.
- **Tradeoff:** 
  - **Gained:** users can change their mind about their message
  - **Gave up:** No history tracking - previous messages are overwritten

### Decision 2: No Error on Delete Non-Existent Message
- **What I chose:** `delete-message` succeeds even if no message exists
- **Why:** This is idempotent behavior - calling it multiple times has the same effect as calling it once. Reduces confusion for users.
- **Tradeoff:**
  - **Gained:** Simpler error handling, no need to check if message exists first
  - **Gave up:** Cannot distinguish between "message deleted" and "no message existed"

### Decision 3: Public Message Reading
- **What I chose:** Any user can read any other user's messages
- **Why:** This is a public registry, like a guest book. The social aspect requires messages to be visible.
- **Tradeoff:**
  - **Gained:** Simplicity, transparency, social interaction
  - **Gave up:** Privacy - messages are fully public

### Decision 4: Message Length Validation
- **What I chose:** Require at least 1 character, max 500 characters
- **Why:** Empty messages serve no purpose and waste space. 500 chars is enough for greetings but prevents abuse.
- **Tradeoff:**
  - **Gained:** Data quality, storage efficiency
  - **Gave up:** Some flexibility (can't store empty placeholder)

## How to Use This Contract

### Function: set-message
- **Purpose:** Store or update a greeting message for the caller
- **Parameters:** 
  - `message`: (string-utf8 500) - The greeting message to store
- **Returns:** `(ok true)` on success, or `(err u100)` if message is empty
- **Example:**
```clarity
(contract-call? .hello-world-registry set-message u"Hello from the blockchain!")
```

### Function: get-message
- **Purpose:** Retrieve the message for any user
- **Parameters:** 
  - `user`: principal - The address of the user whose message to retrieve
- **Returns:** `(some "message")` if user has a message, `none` if not found
- **Example:**
```clarity
(contract-call? .hello-world-registry get-message 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Function: get-my-message
- **Purpose:** Convenience function to retrieve caller's own message
- **Parameters:** None
- **Returns:** `(some "message")` if caller has a message, `none` if not found
- **Example:**
```clarity
(contract-call? .hello-world-registry get-my-message)
```

### Function: delete-message
- **Purpose:** Remove caller's message from the registry
- **Parameters:** None
- **Returns:** `(ok true)` always succeeds
- **Example:**
```clarity
(contract-call? .hello-world-registry delete-message)
```

## Known Limitations
- No message history - only the most recent message is stored
- No character validation beyond length (could store special characters, emojis, etc.)
- No rate limiting - users can update messages as often as they want
- No admin functions - cannot moderate inappropriate messages
- Fixed 500 character limit cannot be changed after deployment

## Future Improvements
- Add message history tracking (array of previous messages)
- Implement content moderation or flagging system
- Add timestamp tracking for when messages were created/updated
- Allow users to make their messages private (opt-in visibility)
- Add batch operations to retrieve multiple messages at once
- Implement pagination for reading messages efficiently

## Testing Notes

### Test Case 1: Set and Retrieve Message
- Called `set-message` with "Hello World!"
- Called `get-my-message` and verified it returned the correct message
- ✅ PASSED

### Test Case 2: Update Existing Message
- Set initial message "First message"
- Called `set-message` again with "Updated message"
- Verified new message replaced the old one
- ✅ PASSED

### Test Case 3: Empty Message Validation
- Attempted to call `set-message` with empty string
- Confirmed it returned error u100
- ✅ PASSED

### Test Case 4: Delete Message
- Set a message, then called `delete-message`
- Called `get-my-message` and verified it returned `none`
- ✅ PASSED

### Test Case 5: Read Other User's Message
- User A set a message
- User B called `get-message` with User A's principal
- Verified User B could read User A's message
- ✅ PASSED

### Test Case 6: Delete Non-Existent Message
- Called `delete-message` without having set a message first
- Verified it returned `(ok true)` without error
- ✅ PASSED