# Telegram Call Notifications Setup

This guide explains how to configure FreePBX to send Telegram notifications for inbound and missed calls.

## Overview

The system uses two custom Asterisk dialplan contexts:
- **telegram-inbound-alert**: Sends notification when a call comes in
- **telegram-missedcall-alert**: Sends notification when a call is not answered

Both contexts are defined in `extensions_custom.conf` and triggered via FreePBX Custom Destinations.

## Configuration File

The configuration is already in place at:
```
data/data/etc/asterisk/extensions_custom.conf
```

### Telegram Credentials

Edit the file to update these values:
```asterisk
exten => s,n,Set(TG_BOT_TOKEN=YOUR_BOT_TOKEN_HERE)
exten => s,n,Set(TG_CHAT_ID_1=YOUR_CHAT_ID_1)
exten => s,n,Set(TG_CHAT_ID_2=YOUR_CHAT_ID_2)
```

**Getting your Bot Token:**
1. Message [@BotFather](https://t.me/BotFather) on Telegram
2. Send `/newbot` and follow instructions
3. Copy the token (format: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

**Getting your Chat ID:**
1. Message [@userinfobot](https://t.me/userinfobot) on Telegram
2. It will reply with your user ID (a number like `260825380`)

## FreePBX GUI Setup

### Step 1: Create Custom Destinations

1. Go to **Admin → Custom Destinations**
2. Click **Add Custom Destination**

**For Inbound Alerts:**
- **Description**: `Telegram Inbound Alert`
- **Target**: `telegram-inbound-alert,s,1`
- **Return**: `Yes` (checked)
- Click **Submit**

**For Missed Call Alerts:**
- **Description**: `Telegram Missed Call Alert`
- **Target**: `telegram-missedcall-alert,s,1`
- **Return**: `Yes` (checked)
- Click **Submit**

### Step 2: Configure Inbound Routes

1. Go to **Connectivity → Inbound Routes**
2. Edit your inbound route (or create a new one)
3. In the **Set Destination** dropdown:
   - Select **Custom Destination**
   - Choose **Telegram Inbound Alert**
4. Click **Submit** and **Apply Config**

### Step 3: Configure Missed Call Notifications

For each extension, ring group, or queue where you want missed call alerts:

1. Edit the extension/ring group/queue
2. Find the **No Answer** or **Timeout** destination
3. Select **Custom Destination**
4. Choose **Telegram Missed Call Alert**
5. Click **Submit** and **Apply Config**

**Example for an Extension:**
- Go to **Applications → Extensions**
- Edit extension (e.g., 100)
- Scroll to **No Answer** section
- Set destination to **Custom Destination → Telegram Missed Call Alert**

**Example for a Ring Group:**
- Go to **Applications → Ring Groups**
- Edit ring group
- Find **Destination if no answer**
- Set to **Custom Destination → Telegram Missed Call Alert**

## Testing

### Test Inbound Alert
1. Call your DID number
2. You should receive a Telegram message like:
   ```
   Incoming call for modeleven (Wien):
   Time: 2026-06-29 14:30:45
   Caller number: +43123456789
   Caller name: John Doe
   Inbound DID: +43987654321
   Channel: PJSIP/trunk-00000001
   ```

### Test Missed Call Alert
1. Call an extension with missed call notification configured
2. Don't answer the call
3. After timeout, you should receive:
   ```
   Missed call on FreePBX
   Time: 2026-06-29 14:35:22
   Caller number: +43123456789
   Caller name: John Doe
   Inbound DID: +43987654321
   Target: 100
   Channel: PJSIP/trunk-00000002
   ```

## Troubleshooting

### Check Asterisk Logs
```bash
docker exec -it freepbx-app tail -f /var/log/asterisk/full
```

Look for lines containing:
- `Entering telegram-inbound-alert`
- `Entering telegram-missedcall-alert`
- `Telegram response chat 1:`
- `Telegram response chat 2:`

### Verify Custom Destination Exists
```bash
docker exec -it freepbx-app asterisk -rx "dialplan show telegram-inbound-alert"
docker exec -it freepbx-app asterisk -rx "dialplan show telegram-missedcall-alert"
```

### Test CURL Function
```bash
docker exec -it freepbx-app asterisk -rx "dialplan show function CURL"
```

### Reload Dialplan After Changes
```bash
docker exec -it freepbx-app asterisk -rx "dialplan reload"
```

Or via FreePBX:
```bash
docker exec -it freepbx-app fwconsole reload
```

### Check Telegram API Response
If messages aren't arriving, check the `TG_RESULT` in logs. Common errors:
- `{"ok":false,"error_code":401,"description":"Unauthorized"}` → Invalid bot token
- `{"ok":false,"error_code":400,"description":"Bad Request: chat not found"}` → Invalid chat ID or bot not added to chat

## Customization

### Change Message Format
Edit the `MSG_RAW` variable in `extensions_custom.conf`:
```asterisk
exten => s,n,Set(MSG_RAW=Your custom message here%0AWith line breaks)
```

Use `%0A` for line breaks and `${URIENCODE(...)}` for special characters.

### Add More Recipients
Add additional chat IDs:
```asterisk
exten => s,n,Set(TG_CHAT_ID_3=ANOTHER_CHAT_ID)
exten => s,n,Set(TG_RESULT=${CURL(https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage,chat_id=${TG_CHAT_ID_3}&text=${MSG_RAW})})
```

### Send to Group Chats
1. Add the bot to your Telegram group
2. Get the group chat ID (negative number like `-1001234567890`)
3. Use it as a chat ID in the configuration

## Security Notes

- The bot token is stored in plain text in the dialplan
- Consider using environment variables or a separate config file for production
- Restrict file permissions: `chmod 640 extensions_custom.conf`
- The bot can only send messages to users who have started a conversation with it

## Files Modified

- `data/data/etc/asterisk/extensions_custom.conf` - Main configuration

## Related Documentation

- [FreePBX Custom Destinations](https://wiki.freepbx.org/display/FPG/Custom+Destinations)
- [Asterisk CURL Function](https://wiki.asterisk.org/wiki/display/AST/Asterisk+18+Function_CURL)
- [Telegram Bot API](https://core.telegram.org/bots/api#sendmessage)
