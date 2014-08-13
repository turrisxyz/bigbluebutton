@sendMessage = ->
  message = $('#newMessageInput').val() # get the message from the input box
  unless (message?.length > 0 and (/\S/.test(message))) # check the message has content and it is not whitespace
    return # do nothing if invalid message

  chattingWith = getInSession('inChatWith')

  if chattingWith isnt "PUBLIC_CHAT" 
    dest = Meteor.Users.findOne("userId": chattingWith)

  messageForServer = { # construct message for server
    "message": message
    "chat_type": if chattingWith is "PUBLIC_CHAT" then "PUBLIC_CHAT" else "PRIVATE_CHAT"
    "from_userid": getInSession("userId")
    "from_username": getUsersName()
    "from_tz_offset": "240"
    "to_username": if chattingWith is "PUBLIC_CHAT" then "public_chat_username" else dest.user.name
    "to_userid": if chattingWith is "PUBLIC_CHAT" then "public_chat_userid" else chattingWith
    "from_lang": "en"
    "from_time": getTime()
    "from_color": "0"
  }
  # console.log 'Sending message to server:'
  # console.log messageForServer
  Meteor.call "sendChatMessagetoServer", getInSession("meetingId"), messageForServer
  $('#newMessageInput').val '' # Clear message box

Template.chatInput.events
  'click #sendMessageButton': (event) ->
    sendMessage()
  'keypress #newMessageInput': (event) -> # user pressed a button inside the chatbox
    if event.which is 13 # Check for pressing enter to submit message
      sendMessage()

Template.chatInput.rendered  = ->
   $('input[rel=tooltip]').tooltip()
   $('button[rel=tooltip]').tooltip()

Template.chatbar.helpers
  getChatGreeting: ->
    greeting = 
    "<p>Welcome to #{getMeetingName()}!</p>
    <p>For help on using BigBlueButton see these (short) <a href='http://bigbluebutton.org/videos/' target='_blank'>tutorial videos</a>.</p>
    <p>To join the audio bridge click the headset icon (upper-left hand corner).  Use a headset to avoid causing background noise for others.</p>
    <br/>
    <p>This server is running BigBlueButton #{getInSession 'bbbServerVersion'}.</p>"

  # This method returns all messages for the user. It looks at the session to determine whether the user is in
  #private or public chat. If true is passed, messages returned are from before the user joined. Else, the messages are from after the user joined
  getFormattedMessagesForChat: () ->
    friend = chattingWith = getInSession('inChatWith') # the recipient(s) of the messages

    if chattingWith is 'PUBLIC_CHAT' # find all public messages
        before = Meteor.Chat.find({'message.chat_type': chattingWith, 'message.from_time': {$lt: String(getInSession("joinedAt"))}}).fetch()
        after = Meteor.Chat.find({'message.chat_type': chattingWith, 'message.from_time': {$gt: String(getInSession("joinedAt"))}}).fetch()
    else
      me = getInSession("userId")
      before = Meteor.Chat.find({ # find all messages between current user and recipient
        'message.chat_type': 'PRIVATE_CHAT',
        $or: [{'message.from_userid': me, 'message.to_userid': friend},{'message.from_userid': friend, 'message.to_userid': me}]
      }).fetch()
      after = []

    greeting = [
      'class': 'chatGreeting',
      'message':
        'message': Template.chatbar.getChatGreeting(),
        'from_username': 'System',
        'from_time': getTime()
    ]

    messages = (before.concat greeting).concat after
    messages
    ###
    # Now after all messages + the greeting have been inserted into our collection, what we have to do is go through all messages
    # and modify them to join all sequential messages by users together so each entries will be chat messages by a user in the same time frame
    # we can use a time frame, so join messages together that are within 5 minutes of eachother, for example
    ###

Template.message.rendered = -> # When a message has been added and finished rendering, scroll to the bottom of the chat
  $('#chatbody').scrollTop($('#chatbody')[0].scrollHeight)

Template.optionsBar.events
  'click .private-chat-user-entry': (event) -> # clicked a user's name to begin private chat
    setInSession 'display_chatPane', true
    setInSession "inChatWith", @userId

    messageForServer =
          "message": "#{getUsersName()} has joined private chat with #{@user.name}."
          "chat_type": "PRIVATE_CHAT"
          "from_userid": getInSession("userId")
          "from_username": getUsersName()
          "from_tz_offset": "240"
          "to_username": @user.name
          "to_userid": @userId
          "from_lang": "en"
          "from_time": getTime()
          "from_color": "0"

    Meteor.call "sendChatMessagetoServer", getInSession("meetingId"), messageForServer

Template.tabButtons.events
  'click .close': (event) -> # user closes private chat
    setInSession 'inChatWith', 'PUBLIC_CHAT'
    setInSession 'display_chatPane', true
    Meteor.call("deletePrivateChatMessages", getInSession("userId"), @userId)
    return false # stops propogation/prevents default

  'click .optionsChatTab': (event) ->
    setInSession 'display_chatPane', false

  'click .privateChatTab': (event) ->
    setInSession 'display_chatPane', true
    console.log ".private"

  'click .publicChatTab': (event) ->
    setInSession 'display_chatPane', true

  'click .tab': (event) -> 
    setInSession "inChatWith", @userId
  
Template.tabButtons.helpers
  getChatbarTabs: ->
    tabs = makeTabs()

  makeTabButton: -> # create tab button for private chat or other such as options
    button = '<li '
    button += 'class="'
    button += 'active ' if getInSession("inChatWith") is @userId
    button += "tab #{@class}\"><a href=\"#\" data-toggle=\"tab\">#{@name}"
    button += '&nbsp;<button class="close closeTab" type="button" >×</button>' if @name isnt 'Public' and @name isnt 'Options'
    button += '</a></li>'
    button
