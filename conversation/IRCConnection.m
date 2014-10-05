//
//  IRCConnection.m
//  conversation
//
//  Created by Toby P on 05/10/14.
//  Copyright (c) 2014 conversation. All rights reserved.
//

#import "IRCConnection.h"

@implementation IRCConnection

- (id)init
{
    if((self = [super init]))
    {
        return self;
    }
    return nil;
}

- (void)connectToHost:(NSString *)host onPort:(UInt16)port withPassword:(NSString *)password nick:(NSString *)nick ident:(NSString *)ident realName:(NSString *)realname
{
    NSLog(@"Ready");
    NSError *err = nil;
    asyncSocket = [[AsyncSocket alloc] initWithDelegate:self];
    if(![asyncSocket connectToHost:host onPort:port error:&err]) {
        NSLog(@"Error: %@", err);
    } else {
        NSLog(@"Connected!");
    }
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"onSocket:%p didConnectToHost:%@ port:%hu", sock, host, port);
    
    // Configure SSL/TLS settings
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:3];
    
    // If you simply want to ensure that the remote host's certificate is valid,
    // then you can use an empty dictionary.
    
    // If you know the name of the remote host, then you should specify the name here.
    //
    // NOTE:
    // You should understand the security implications if you do not specify the peer name.
    // Please see the documentation for the startTLS method in AsyncSocket.h for a full discussion.
    
    [settings setObject:@"somedomain.com" forKey:(NSString *)kCFStreamSSLPeerName];
    
    // To connect to a test server, with a self-signed certificate, use settings similar to this:
    
    //	// Allow expired certificates
    //	[settings setObject:[NSNumber numberWithBool:YES]
    //				 forKey:(NSString *)kCFStreamSSLAllowsExpiredCertificates];
    //
    //	// Allow self-signed certificates
    //	[settings setObject:[NSNumber numberWithBool:YES]
    //				 forKey:(NSString *)kCFStreamSSLAllowsAnyRoot];
    //
    //	// In fact, don't even validate the certificate chain
    //	[settings setObject:[NSNumber numberWithBool:NO] forKey:(NSString *)kCFStreamSSLValidatesCertificateChain];
    
    [sock startTLS:settings];
    
    // You can also pass nil to the startTLS method, which is the same as passing an empty dictionary.
    // Again, you should understand the security implications of doing so.
    // Please see the documentation for the startTLS method in AsyncSocket.h for a full discussion.
}

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    if(tag == 0)
    {
        [sock readDataToData:[AsyncSocket CRLFData] withTimeout:-1 tag:0];
    }
    NSLog(@"Data send");
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length] - 2)];
    NSString *msg = [[NSString alloc] initWithData: strData encoding:NSUTF8StringEncoding];
    if(msg)
    {
        NSLog(@"Readed msg: %@",msg);
        //[self logMessage:msg];
    }
    else
    {
        NSLog(@"Readed msg error: %@",msg);
        //[self logError:@"Error converting received data into UTF-8 String"];
    }
    
    // Even if we were unable to write the incoming data to the log,
    // we're still going to echo it back to the client.
    [sock writeData:data withTimeout:-1 tag:1];
}

- (void)onSocketDidSecure:(AsyncSocket *)sock
{
    NSLog(@"onSocketDidSecure:%p", sock);
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
    NSLog(@"onSocket:%p willDisconnectWithError:%@", sock, err);
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
    NSLog(@"onSocketDidDisconnect:%p", sock);
}

@end
