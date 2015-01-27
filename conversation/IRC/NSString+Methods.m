/*
 Copyright (c) 2014-2015, Tobias Pollmann, Alex Sørlie Glomsaas.
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
    /* "localhost" is a unix alias to 127.0.0.1 and we can accept it as valid */
    if ([self caseInsensitiveCompare:@"localhost"] == NSOrderedSame) {
        return YES;
    }
    
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
    
    NSString *regex = @"^(([a-zA-Z]{1})|([a-zA-Z]{1}[a-zA-Z]{1})|([a-zA-Z]{1}[0-9]{1})|([0-9]{1}[a-zA-Z]{1})|([a-zA-Z0-9][a-zA-Z0-9-_]{1,61}[a-zA-Z0-9]))\\.([a-zA-Z]{2,6}|[a-zA-Z0-9-]{2,30}\\.[a-zA-Z]{2,20})$";
    NSPredicate *hostValidation = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    return [hostValidation evaluateWithObject: self];
}

- (BOOL) isValidNickname:(IRCClient *)client
{
    int maxNickLength = [[[client featuresSupportedByServer] objectForKey:@"NICKLEN"] intValue];
    if (maxNickLength == 0) {
        maxNickLength = 16;
    }
    
    // Check length
    if (self.length < 2 || self.length > maxNickLength)
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

-(BOOL)isValidHostname
{
    if ([self length] < 1 || [self length] > 255) return NO;
    NSCharacterSet *hostnameCharacterSet = ((AppDelegate *)[UIApplication sharedApplication].delegate).ircCharacterSets.hostnameCharacterSet;
    if ([self rangeOfCharacterFromSet:hostnameCharacterSet].location != NSNotFound) return NO;
    
    return YES;
}

- (BOOL)isValidWildcardIgnoreMask
{
    NSArray *nicknameAndHostmask = [self componentsSeparatedByString:@"!"];
    if ([nicknameAndHostmask count] == 2) {
        NSArray *usernameAndHostname = [nicknameAndHostmask[1] componentsSeparatedByString:@"@"];
        if ([usernameAndHostname count] == 2) {
            return YES;
        }
    }
    return NO;
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

- (NSData *)dataUsingEncodingFromConfiguration:(IRCConnectionConfiguration *)configuration
{
    NSStringEncoding encoding;
    if (configuration && configuration.socketEncodingType) {
        encoding = configuration.socketEncodingType;
    } else {
        encoding = NSUTF8StringEncoding;
    }
    return [self dataUsingEncoding:encoding allowLossyConversion:NO];
}

- (NSString*)stringByTruncatingToWidth:(CGFloat)width withAttributes:(NSDictionary *)attributes
{
    NSString *ellipsis = @"…";
    NSMutableString *truncatedString = [self mutableCopy];
    
    // Make sure string is longer than requested width
    if ([self sizeWithAttributes:attributes].width > width) {
        width -= [ellipsis sizeWithAttributes:attributes].width;
        NSRange range = {floor(truncatedString.length / 2), 1};

        // Loop, deleting characters until string fits within width
        while ([truncatedString sizeWithAttributes:attributes].width > width) {

            // Delete character at the middle
            [truncatedString deleteCharactersInRange:range];
            range.location = floor(truncatedString.length / 2)-floor(range.length / 2);
            range.length++;
        }
        
        [truncatedString replaceCharactersInRange:range withString:ellipsis];
    }
    
    return truncatedString;
}

- (BOOL)getUserHostComponents:(NSString **)nickname username:(NSString **)username hostname:(NSString **)hostname onClient:(IRCClient *)client
{
    NSCharacterSet *hostmaskCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"!@"];
    NSArray *components = [self componentsSeparatedByCharactersInSet:hostmaskCharacterSet];
    
    if ([components count] != 3) return NO;
    
    *nickname = [components objectAtIndex:0];
    *username = [components objectAtIndex:1];
    *hostname = [components objectAtIndex:2];
    
    #define AssertValidInput(x) if (x == NO) return NO
    
    AssertValidInput([*nickname isValidNickname:client]);
    AssertValidInput([*username isValidUsername]);
    AssertValidInput([*hostname isValidHostname]);
    
    return YES;
}

/* 
 Copyright (c) 2010 - 2015 Codeux Software, LLC & respective contributors.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of Textual and/or "Codeux Software, LLC", nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 SUCH DAMAGE.
 */

- (NSString *)removeIRCFormatting
{
    if ([self length] == 0) return @"";
    
    NSInteger pos = 0;
    NSInteger len = [self length];
    
    NSInteger buflen = (len * sizeof(UniChar));
    
    UniChar *src = alloca(buflen);
    UniChar *buf = alloca(buflen);
    
    [self getCharacters:src range:NSMakeRange(0, len)];
    
    for (NSInteger i = 0; i < len; ++i) {
        unichar c = src[i];
        
        if (c < 0x20) {
            switch (c) {
                case 0x2:
                case 0xf:
                case 0x16:
                case 0x1d:
                case 0x1f:
                {
                    break;
                }
                case 0x3:
                {
                    /* ============================================= */
                    /* Begin color stripping.						 */
                    /* ============================================= */

                    if ((i + 1) >= len) {
                        continue;
                    }
                    
                    UniChar d = src[(i + 1)];
                    
                    if (('0' <= (d) && (d) <= '9') == NO) {
                        continue;
                    }
                    
                    i++;
                    
                    // ---- //
                    
                    if ((i + 1) >= len) {
                        continue;
                    }
                    
                    UniChar e = src[(i + 1)];
                    
                    if (('0' <= (e) && (e) <= '9') == NO && (e) != (',')) {
                        continue;
                    }
                    
                    i++;
                    
                    // ---- //
                    
                    if ((e == ',') == NO) {
                        if ((i + 1) >= len) {
                            continue;
                        }
                        
                        UniChar f = src[(i + 1)];
                        
                        if ((f) != (',')) {
                            continue;
                        }
                        
                        i++;
                    }
                    
                    // ---- //
                    
                    if ((i + 1) >= len) {
                        continue;
                    }
                    
                    UniChar g = src[(i + 1)];
                    
                    if (('0' <= (g) && (g) <= '9') == NO) {
                        i--;
                        
                        continue;
                    }
                    
                    i++;
                    
                    // ---- //
                    
                    if ((i + 1) >= len) {
                        continue;
                    }
                    
                    UniChar h = src[(i + 1)];
                    
                    if (('0' <= (h) && (h) <= '9') == NO) {
                        continue;
                    }
                    
                    // ---- //
                    i++;
                    
                    break;
                    
                    /* ============================================= */
                    /* End color stripping.							 */
                    /* ============================================= */
                }
                default:
                {
                    buf[pos++] = c;
                    
                    break;
                }
            }
        } else {
            buf[pos++] = c;
        }
    }
    
    return [NSString stringWithCharacters:buf length:pos];
}

@end
