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

#import <Foundation/Foundation.h>
#import "GCDAsyncSocket.h"
#import "NSString+Methods.h"
#import "IRCCertificateTrust.h"

@class IRCClient;

@interface IRCConnection : NSObject {
    GCDAsyncSocket *socket;
    dispatch_queue_t queue;
}


/*!
 *    @brief  Creates an IRCConnection based on associated IRCClient object.
 *
 *    @param client An IRCClient object to use for retrieving connection information and parsing.
 *
 *    @return An IRCConnection in an initialised disconnected state.
 */
- (id)initWithClient:(IRCClient *)client;


/*!
 *    @brief Attempt an IRC connection to a server.
 *
 *    @param host       The domain or IP address of the host to connect to.
 *    @param port       The port number of the host to connect to.
 *    @param sslEnabled Whether or not to attempt an SSL connection.
 */
- (void)connectToHost:(NSString *)host onPort:(UInt16)port useSSL:(BOOL)sslEnabled;

/*!
 *    @brief  Close the connection and remove all pending data.
 */
- (void)close;

/*!
 *    @brief  Enable flood control on the socket.
 */
- (void)enableFloodControl;

/*!
 *    @brief  Disable flood control on the socket.
 */
- (void)disableFloodControl;

/*!
 *    @brief  Attempt to send a message to the server using the pre-defined encoding settings.
 *
 *    @warning Subject to flood control.
 *
 *    @param line The message to send to the server.
 */
- (void)send:(NSString *)line;

@end
