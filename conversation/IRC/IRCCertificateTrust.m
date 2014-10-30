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

#import "IRCCertificateTrust.h"
#import "ConversationItemView.h"
#import "CertificateItemRow.h"

#define NSLocalisedString(x) NSLocalizedString(x, x)

@implementation IRCCertificateTrust

- (instancetype)init:(SecTrustRef)trust onClient:(IRCClient *)client {
    if ((self = [super init])) {
        self.trustReference = trust;
        self.subjectInformation = nil;
        self.trustStatus = AWAITING_RESPONSE;
        self.issuerInformation = nil;
        self.certificateInformation = nil;
        self.client = client;
        return self;
    }
    return nil;
}

- (void)requestTrustFromUser:(void (^)(BOOL shouldTrustPeer))completionHandler
{
    CFIndex count = SecTrustGetCertificateCount(self.trustReference);
    if (count > 0) {
        SecCertificateRef certificate = SecTrustGetCertificateAtIndex(self.trustReference, 0);
        NSData *certificateData = (__bridge NSData *) SecCertificateCopyData(certificate);
        const unsigned char *certificateDataBytes = (const unsigned char *)[certificateData bytes];
        X509 *certificateX509 = d2i_X509(NULL, &certificateDataBytes, [certificateData length]);
        
        self.subjectInformation      = [IRCCertificateTrust getCertificateSubject:certificateX509];
        self.issuerInformation       = [IRCCertificateTrust getCertificateIssuer:certificateX509];
        self.certificateInformation  = [IRCCertificateTrust getCertificateAlgorithmInformation:certificateX509];
        
        CertificateItemRow *certificateSignature = [self.certificateInformation objectAtIndex:6];
        for (NSString *signature in [[self.client configuration] trustedSSLSignatures]) {
            if ([signature isEqualToString:[certificateSignature itemDescription]]) {
                completionHandler(YES);
                return;
            }
        }
        self.signature = certificateSignature.itemDescription;
        
        ConversationListViewController *controller = ((AppDelegate *)[UIApplication sharedApplication].delegate).conversationsController;
        [controller requestUserTrustForCertificate:self];
        
        [self checkTrustActionCompleted:completionHandler];
    }
}

- (void)checkTrustActionCompleted:(void (^)(BOOL shouldTrustPeer))completionHandler
{
    switch (self.trustStatus) {
        case CERTIFICATE_ACCEPTED: {
            [self addSignature:self.signature];
            completionHandler(YES);
            break;
        }
        
        case CERTIFICATE_DENIED: {
            completionHandler(NO);
            [self.client disconnect];
            break;
        }
            
        case AWAITING_RESPONSE: {
            SEL selector = @selector(checkTrustActionCompleted:);
            NSMethodSignature *signature = [self methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:self];
            [invocation setSelector:selector];
            [invocation setArgument:&completionHandler atIndex:2];
            [NSTimer scheduledTimerWithTimeInterval:0.1 invocation:invocation repeats:NO];
            break;
        }
    }
}

- (void)addSignature:(NSString *)signature
{
    NSMutableArray *signatures = [[[self.client configuration] trustedSSLSignatures] mutableCopy];
    [signatures addObject:signature];
    self.client.configuration.trustedSSLSignatures = signatures;
}

- (void)receivedTrustFromUser:(BOOL)trust
{
    if (trust == YES) {
        self.trustStatus = CERTIFICATE_ACCEPTED;
    } else {
        self.trustStatus = CERTIFICATE_DENIED;
    }
}

+ (NSArray *) getCertificateSubject:(X509 *)certificateX509
{
    NSMutableArray *subject = [[NSMutableArray alloc] init];
    if (certificateX509 != NULL) {
        X509_NAME *subjectX509Name = X509_get_subject_name(certificateX509);
        
        if (subjectX509Name != NULL) {
            [subject addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Country") andDescription:getKeyString(NID_countryName, subjectX509Name)]];
            [subject addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Province/State") andDescription:getKeyString(NID_stateOrProvinceName, subjectX509Name)]];
            [subject addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Locality") andDescription:getKeyString(NID_localityName, subjectX509Name)]];
            [subject addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Organisation") andDescription:getKeyString(NID_organizationName, subjectX509Name)]];
            [subject addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Organisational Unit") andDescription:getKeyString(NID_organizationalUnitName, subjectX509Name)]];
            [subject addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Common Name") andDescription:getKeyString(NID_commonName, subjectX509Name)]];
            [subject addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Email Address") andDescription:getKeyString(NID_pkcs9_emailAddress, subjectX509Name)]];
        }
    }
    return subject;
}

+ (NSArray *) getCertificateIssuer:(X509 *)certificateX509
{
    NSMutableArray *issuer = [[NSMutableArray alloc] init];
    if (certificateX509 != NULL) {
        X509_NAME *issuerX509Name = X509_get_issuer_name(certificateX509);
        
        if (issuerX509Name != NULL) {
            [issuer addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Country") andDescription:getKeyString(NID_countryName, issuerX509Name)]];
            [issuer addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Province/State") andDescription:getKeyString(NID_stateOrProvinceName, issuerX509Name)]];
            [issuer addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Locality") andDescription:getKeyString(NID_localityName, issuerX509Name)]];
            [issuer addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Organisation") andDescription:getKeyString(NID_organizationName, issuerX509Name)]];
            [issuer addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Organisational Unit") andDescription:getKeyString(NID_organizationalUnitName, issuerX509Name)]];
            [issuer addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Common Name") andDescription:getKeyString(NID_commonName, issuerX509Name)]];
            [issuer addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Email Address") andDescription:getKeyString(NID_pkcs9_emailAddress, issuerX509Name)]];
        }
    }
    return issuer;
}

+ (NSArray *) getCertificateAlgorithmInformation:(X509 *)certificateX509
{
    NSMutableArray *algorithm = [[NSMutableArray alloc] init];
    if (certificateX509 != NULL) {
        char alg[128];
        OBJ_obj2txt(alg, sizeof(alg), certificateX509->sig_alg->algorithm, 0);
        NSString *signatureAlgorithm;
        if (alg) {
            signatureAlgorithm = [NSString stringWithUTF8String:alg];
        } else {
            signatureAlgorithm = @"";
        }
        [algorithm addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Algorithm") andDescription:signatureAlgorithm]];
        
        NSString *version = [NSString stringWithFormat:@"%ld", X509_get_version(certificateX509)];
        [algorithm addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Version") andDescription:version]];
        
        long serial = ASN1_INTEGER_get(X509_get_serialNumber(certificateX509));
        [algorithm addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Serial") andDescription:[NSString stringWithFormat:@"%ld", serial]]];
        
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"dd/MM/yyyy HH:mm:ss"];
        
        NSDate *certStartTime = CertificateGetStartDate(certificateX509);
        NSString *startTimeString = [formatter stringFromDate:certStartTime];
        [algorithm addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Not Valid Before") andDescription:startTimeString]];
        
        NSDate *certExpireTime = CertificateGetExpiryDate(certificateX509);
        NSString *expireTimeString = [formatter stringFromDate:certExpireTime];
        [algorithm addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Not Valid After") andDescription:expireTimeString]];
        
        ASN1_BIT_STRING *pubKey = X509_get0_pubkey_bitstr(certificateX509);
        NSString *publicKey = @"";
        for (int i = 0; i < pubKey->length; i++) {
            publicKey = [publicKey stringByAppendingString:[NSString stringWithFormat:@"%02X ", pubKey->data[i]]];
        }
        
        [algorithm addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Public Key") andDescription:publicKey]];
        
        ASN1_BIT_STRING *signature = certificateX509->signature;
        NSString *signatureKey = @"";
        for (int i = 0; i < signature->length; i++) {
            signatureKey = [signatureKey stringByAppendingString:[NSString stringWithFormat:@"%02X ", signature->data[i]]];
        }
        
        [algorithm addObject:[[CertificateItemRow alloc] initWithName:NSLocalisedString(@"Signature") andDescription:signatureKey]];
    }
    return algorithm;
}

static NSString *getKeyString(int nid, X509_NAME *issuer)
{
    int index = X509_NAME_get_index_by_NID(issuer, nid, -1);
    X509_NAME_ENTRY *issuerNameEntry = X509_NAME_get_entry(issuer, index);
    if (issuerNameEntry) {
        ASN1_STRING *issuerNameASN1 = X509_NAME_ENTRY_get_data(issuerNameEntry);
        if (issuerNameASN1 != NULL) {
            unsigned char *issuerName = ASN1_STRING_data(issuerNameASN1);
            return [NSString stringWithUTF8String:(char *)issuerName];
        }
    }
    return @"";
}

static NSDate *CertificateGetStartDate(X509 *certificateX509)
{
    NSDate *startDate = nil;
    
    if (certificateX509 != NULL) {
        ASN1_TIME *certificateStartASN1 = X509_get_notBefore(certificateX509);
        if (certificateStartASN1 != NULL) {
            ASN1_GENERALIZEDTIME *certificateStartASN1Generalized = ASN1_TIME_to_generalizedtime(certificateStartASN1, NULL);
            if (certificateStartASN1Generalized != NULL) {
                unsigned char *certificateStartData = ASN1_STRING_data(certificateStartASN1Generalized);
                
                NSString *startTimeStr = [NSString stringWithUTF8String:(char *)certificateStartData];
                NSDateComponents *startDateComponents = [[NSDateComponents alloc] init];
                
                startDateComponents.year   = [[startTimeStr substringWithRange:NSMakeRange(0, 4)] intValue];
                startDateComponents.month  = [[startTimeStr substringWithRange:NSMakeRange(4, 2)] intValue];
                startDateComponents.day    = [[startTimeStr substringWithRange:NSMakeRange(6, 2)] intValue];
                startDateComponents.hour   = [[startTimeStr substringWithRange:NSMakeRange(8, 2)] intValue];
                startDateComponents.minute = [[startTimeStr substringWithRange:NSMakeRange(10, 2)] intValue];
                startDateComponents.second = [[startTimeStr substringWithRange:NSMakeRange(12, 2)] intValue];
                
                NSCalendar *calendar = [NSCalendar currentCalendar];
                startDate = [calendar dateFromComponents:startDateComponents];
            }
        }
    }
    return startDate;
}

static NSDate *CertificateGetExpiryDate(X509 *certificateX509)
{
    NSDate *expiryDate = nil;
    
    if (certificateX509 != NULL) {
        ASN1_TIME *certificateExpiryASN1 = X509_get_notAfter(certificateX509);
        if (certificateExpiryASN1 != NULL) {
            ASN1_GENERALIZEDTIME *certificateExpiryASN1Generalized = ASN1_TIME_to_generalizedtime(certificateExpiryASN1, NULL);
            if (certificateExpiryASN1Generalized != NULL) {
                unsigned char *certificateExpiryData = ASN1_STRING_data(certificateExpiryASN1Generalized);
                
                NSString *expiryTimeStr = [NSString stringWithUTF8String:(char *)certificateExpiryData];
                NSDateComponents *expiryDateComponents = [[NSDateComponents alloc] init];
                
                expiryDateComponents.year   = [[expiryTimeStr substringWithRange:NSMakeRange(0, 4)] intValue];
                expiryDateComponents.month  = [[expiryTimeStr substringWithRange:NSMakeRange(4, 2)] intValue];
                expiryDateComponents.day    = [[expiryTimeStr substringWithRange:NSMakeRange(6, 2)] intValue];
                expiryDateComponents.hour   = [[expiryTimeStr substringWithRange:NSMakeRange(8, 2)] intValue];
                expiryDateComponents.minute = [[expiryTimeStr substringWithRange:NSMakeRange(10, 2)] intValue];
                expiryDateComponents.second = [[expiryTimeStr substringWithRange:NSMakeRange(12, 2)] intValue];
                
                NSCalendar *calendar = [NSCalendar currentCalendar];
                expiryDate = [calendar dateFromComponents:expiryDateComponents];
            }
        }
    }
    return expiryDate;
}


@end