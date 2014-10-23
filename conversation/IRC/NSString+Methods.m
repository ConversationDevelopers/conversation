/*
 Copyright (c) 2014, Tobias Pollmann, Alex Sørlie Glomsaas.
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holders nor the names of its contributors
 may be used to endorse or promote products derived from this software without
 specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "NSString+Methods.h"
#import "IRCClient.h"
#include <arpa/inet.h>

@implementation NSString (Helpers)

- (BOOL) isValidChannelName:(IRCClient *)client
{
    /* Get the channel prefix characters allowed by the server */
    NSString *acceptedChannelPrefixesByServer = [IRCClient getChannelPrefixCharacters:client];
    
    /* Turn both strings into character arrays for parsing */
    char* prefixes = malloc([acceptedChannelPrefixesByServer length]);
    strcpy(prefixes, [acceptedChannelPrefixesByServer UTF8String]);
    char* prefixesBeforeIteration = prefixes;
    
    char*  channel = malloc([self length]+1);
    strcpy(channel, [self UTF8String]);
    char* channelBeforeIteration = channel;
    
    /* Some IRC bouncers prefix special channels with a '~' we will skip this */
    if (*channel == '~') {
        channel++;
    }
    
    BOOL channelHasPrefix = NO;
    
    /* Iterate over prefixes accepted by the server and set YES if we find a match. */
    while (*prefixes != '\0') {
        if (*prefixes == *channel) {
            channelHasPrefix = YES;
            break;
        }
        prefixes++;
    }
    if (channelHasPrefix) {
        /* Continue iterating on the channel name and halt if we find an invalid character */
        while (*channel != '\0') {
            if (*channel == ' ' || *channel == '\007' || *channel == ',') {
                channel = channelBeforeIteration;
                free(channel);
                prefixes = prefixesBeforeIteration;
                free(prefixes);
                return NO;
            }
            channel++;
        }
        channel = channelBeforeIteration;
        free(channel);
        prefixes = prefixesBeforeIteration;
        free(prefixes);
        return YES;
    } else {
        channel = channelBeforeIteration;
        free(channel);
        prefixes = prefixesBeforeIteration;
        free(prefixes);
        return NO;
    }
    return NO;
}

- (BOOL) isValidServerAddress
{
    /* Convert address to character array */
    const char* addressAsCharArray = [self UTF8String];
    
    /* Check if the address is a valid IPv4 address */
    struct in_addr dst;
    int isIPv4Address = inet_pton(AF_INET, addressAsCharArray, &(dst.s_addr));
    if (isIPv4Address == 1) {
        return YES;
    }
    
    /* Check if the address is a valid IPv6 address */
    struct in6_addr dst6;
    int isIPv6Address = inet_pton(AF_INET6, addressAsCharArray, &dst6);
    if (isIPv6Address == 1) {
        return YES;
    }
    
    NSString *regex = @"^(([a-zA-Z]{1})|([a-zA-Z]{1}[a-zA-Z]{1})|([a-zA-Z]{1}[0-9]{1})|([0-9]{1}[a-zA-Z]{1})|([a-zA-Z0-9][a-zA-Z0-9-_]{1,61}[a-zA-Z0-9]))\\.([a-zA-Z]{2,6}|[a-zA-Z0-9-]{2,30}\\.[a-zA-Z]{2,3})$";
    NSPredicate *hostValidation = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    return [hostValidation evaluateWithObject: self];
}

- (BOOL) isValidNickname:(IRCClient *)client
{
    int maxNickLength = 0;
    if (client) {
        maxNickLength = [[[client featuresSupportedByServer] objectForKey:@"NICKLEN"] intValue];
    }
    if (maxNickLength == 0) {
        maxNickLength = 16;
    }
    
    // Check length
    if (self.length < 2 || self.length > 16)
        return NO;
    
    // Check for invalid characters
    NSCharacterSet *chars = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_-\[]|{}^`"] invertedSet];
    if([self rangeOfCharacterFromSet:chars].location != NSNotFound)
        return NO;
    
    // Check if first character is a digit
    NSCharacterSet *number = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    if([self rangeOfCharacterFromSet:number].location == 0)
        return NO;
    return YES;
}

- (BOOL)isValidUsername
{
    /* Validate that length is 1 or larger */
    if (self.length < 1) {
        return NO;
    }
    
    /* Parse username and ensure it does not contain carriage return, line feed, @, or !. */
    const char* username = [self UTF8String];
    while (*username != '\0') {
        if (*username == '\010' || *username == '\014' || *username == '@' || *username == '!') {
            return NO;
        }
        username++;
    }
    return YES;
}

+ (NSString *) stringWithCString:(const char *)string usingEncodingPreference:(IRCConnectionConfiguration *)configuration
{
    NSStringEncoding encoding;
    if (configuration && configuration.socketEncodingType) {
        encoding = configuration.socketEncodingType;
    } else {
        encoding = NSUTF8StringEncoding;
    }
    NSString *encodedString;
    encodedString = [NSString stringWithCString:string encoding:encoding];
    if (encodedString == nil) {
        encodedString = [NSString stringWithCString:string encoding:NSASCIIStringEncoding];
    }
    return encodedString;
}

- (NSData *)dataUsingEncoding:(IRCConnectionConfiguration *)configuration
{
    NSStringEncoding encoding;
    if (configuration && configuration.socketEncodingType) {
        encoding = configuration.socketEncodingType;
    } else {
        encoding = NSUTF8StringEncoding;
    }
    return [self dataUsingEncoding:encoding allowLossyConversion:NO];
}
@end
