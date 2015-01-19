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

#import "IRCMessageIndex.h"

@implementation IRCMessageIndex

static NSArray *IRCMessageIndexReference = nil;

+ (NSUInteger)indexValueFromString:(NSString *)key
{
    /* Converts a string into its appropriate MessageType enum value by using its correlated position in the messageIndex array for the IRC parser.
     It is important that elements are in the same order in MessageType and messageIndex or the parser will start activating the wrong commands. */
    return [[IRCMessageIndex messageIndex] indexOfObject:key];
}

+ (NSUInteger)capIndexValueFromString:(NSString *)key
{
    /* Converts a string into its appropriate CapMessageType using its correlated position in the IRCV3capabilityCommandIndex array.
     As with messageIndex these must be in the correct order to function. */
    return [[IRCMessageIndex IRCV3capabilityCommandIndex] indexOfObject:key];
}

+ (NSArray *)IRCV3capabilityCommandIndex
{
    return @[
        @"LS",
        @"ACK",
        @"NAK",
        @"CLEAR"
    ];
}

+ (NSArray *)messageIndex
{
   return @[
        @"PING",
        @"ERROR",
        @"AUTHENTICATE",
        @"CAP",
        @"PRIVMSG",
        @"NOTICE",
        @"JOIN",
        @"PART",
        @"QUIT",
        @"TOPIC",
        @"KICK",
        @"MODE",
        @"NICK",
        @"SQUIT",
        @"AWAY",
        @"001",
        @"002",
        @"003",
        @"004",
        @"005",
        @"200",
        @"201",
        @"202",
        @"203",
        @"204",
        @"205",
        @"206",
        @"207",
        @"208",
        @"209",
        @"210",
        @"211",
        @"212",
        @"219",
        @"221",
        @"234",
        @"235",
        @"242",
        @"243",
        @"251",
        @"252",
        @"253",
        @"254",
        @"255",
        @"256",
        @"257",
        @"258",
        @"259",
        @"261",
        @"262",
        @"263",
        @"301",
        @"302",
        @"303",
        @"305",
        @"306",
        @"311",
        @"312",
        @"313",
        @"314",
        @"315",
        @"317",
        @"318",
        @"319",
        @"322",
        @"323",
        @"324",
        @"325",
        @"331",
        @"332",
        @"341",
        @"346",
        @"347",
        @"348",
        @"349",
        @"351",
        @"352",
        @"353",
        @"364",
        @"365",
        @"366",
        @"367",
        @"368",
        @"369",
        @"371",
        @"372",
        @"374",
        @"375",
        @"376",
        @"381",
        @"382",
        @"383",
        @"391",
        @"392",
        @"393",
        @"394",
        @"395",
        @"401",
        @"402",
        @"403",
        @"404",
        @"405",
        @"406",
        @"407",
        @"408",
        @"409",
        @"411",
        @"412",
        @"413",
        @"415",
        @"421",
        @"422",
        @"423",
        @"424",
        @"431",
        @"432",
        @"433",
        @"436",
        @"437",
        @"441",
        @"442",
        @"443",
        @"444",
        @"445",
        @"446",
        @"451",
        @"461",
        @"462",
        @"463",
        @"464",
        @"465",
        @"466",
        @"567",
        @"471",
        @"472",
        @"473",
        @"474",
        @"475",
        @"476",
        @"477",
        @"478",
        @"481",
        @"482",
        @"483",
        @"484",
        @"485",
        @"491",
        @"501",
        @"502",
        @"900",
        @"901",
        @"902",
        @"903",
        @"904",
        @"905",
        @"906",
        @"907",
        @"908"
    ];
}

@end
