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

@implementation NSString (Helpers)

- (BOOL) isValidChannelName:(IRCClient *)client
{
    /* Validate that parameters are valid before continuing */
    if ([self isKindOfClass:[NSString class]] && client) {
        
        /* Get the channel prefix characters allowed by the server */
        NSString *acceptedChannelPrefixesByServer = [[client featuresSupportedByServer] objectForKey:@"CHANTYPES"];
        if (acceptedChannelPrefixesByServer == nil) {
            /* For some reson the server does not provide this information, so we will use the
             standard characters defined by the RFC http://tools.ietf.org/html/rfc1459#section-1.3  */
            acceptedChannelPrefixesByServer = @"#&";
        }
        
        /* Turn both strings into character arrays for parsing */
        char* prefixes = malloc([acceptedChannelPrefixesByServer length]);
        strcpy(prefixes, [acceptedChannelPrefixesByServer UTF8String]);
        char*  channel = malloc([self length]);
        strcpy(channel, [self UTF8String]);
        
        /* Some IRC bouncers prefix special channels with a '~' we will skip this */
        if (*channel == '~') {
            channel++;
        }
        
        while (*prefixes != '\0') {
            if (*prefixes == *channel) {
                return YES;
            }
        }
    }
    return NO;
}

@end
