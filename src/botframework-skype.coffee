# Description:
#   Middleware to make Hubot work well with Skype
#
# Commands:
#	None
#
# Notes:
#   1. Typing indicator support
#   3. Properly handles chat vs. channel messages
#   5. Properly handles image responses.
#
# Author:
#	billbliss
#
# Modified by:
# Leonardo Chaia <lchaia@astonishinglab.com>
# 
# Inspired on msteams-middleware from Microsoft:
# https://github.com/Microsoft/BotFramework-Hubot/blob/master/src/msteams-middleware.coffee
# All Credits to Microsoft
# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license.

{ Robot, TextMessage, Message, User } = require 'hubot'
{ BaseMiddleware, registerMiddleware } = require('hubot-botframework').Middleware;
LogPrefix = "hubot-skypefixer:"

class SkypeFixerMiddleware extends BaseMiddleware
    toReceivable: (activity) ->
        @robot.logger.info "#{LogPrefix} toReceivable"

        # Get the user
        user = getUser(activity)
        user = @robot.brain.userForId(user.id, user)

        # We don't want to save the activity or room in the brain since its something that changes per chat.
        user.activity = activity
        user.room = getRoomId(activity)

        if activity.type == 'message'
            activity = fixActivityForHubot(activity, @robot)
            message = new TextMessage(user, activity.text, activity.address.id)
            return message

        return new Message(user)

    toSendable: (context, message) ->
        @robot.logger.info "#{LogPrefix} toSendable"
        activity = context?.user?.activity

        response = message
        if typeof message is 'string'
            response =
                type: 'message'
                text: message
                address: activity?.address
            
            imageAttachment = convertToImageAttachment(message)
            if imageAttachment?
                delete response.text
                response.attachments = [imageAttachment]

        typingMessage =
          type: "typing"
          address: activity?.address

        return [typingMessage, response]

    #############################################################################
    # Helper methods for generating richer messages
    #############################################################################

    imageRegExp = /^(https?:\/\/.+\/(.+)\.(jpg|png|gif|jpeg$))/

    # Generate an attachment object from the first image URL in the message
    convertToImageAttachment = (message) ->
        if not typeof message is 'string'
            return null

        result = imageRegExp.exec(message)
        if result?
            attachment =
                contentUrl: result[1]
                name: result[2]
                contentType: "image/#{result[3]}"
            return attachment

        return null
        
    # Fetches the user object from the activity
    getUser = (activity) ->
        user =
            id: activity?.address?.user?.id,
            name: activity?.address?.user?.name,
            tenant: getTenantId(activity)
        return user

    # Fetches the room id from the activity
    getRoomId = (activity) ->
        return activity?.address?.conversation?.id

    # Fetches the tenant id from the activity
    getTenantId = (activity) ->
        return activity?.sourceEvent?.tenant?.id

    # Fixes the activity to have the proper information for Hubot
    # Prepends hubot's name to the message if this is a direct message.
    fixActivityForHubot = (activity, robot) ->
        if not activity?.text? || typeof activity.text isnt 'string'
            return activity
        myChatId = activity?.address?.bot?.id
        if not myChatId?
            return activity

        # prepends the robot's name for direct messages
        roomId = getRoomId(activity)
        if roomId? and not roomId.startsWith("19:") and not activity.text.toLowerCase().startsWith(robot.name.toLowerCase())
            activity.text = "#{robot.name} #{activity.text}"
            
        return activity

    escapeRegExp = (str) ->
        return str.replace(/[\-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&")


registerMiddleware 'skype', SkypeFixerMiddleware
module.exports = SkypeFixerMiddleware