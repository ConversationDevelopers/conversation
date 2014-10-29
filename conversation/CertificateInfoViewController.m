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

#import "CertificateInfoViewController.h"
#import "CertificateItemRow.h"

static unsigned short SubjectInformationSection = 0;
static unsigned short IssuerInformationSection = 1;
static unsigned short CertificateInformationSection = 2;

@implementation CertificateInfoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationController.navigationBar.tintColor = [UIColor lightGrayColor];
    self.navigationController.navigationBar.barStyle = UIBarStyleBlackOpaque;
    self.navigationController.navigationBar.translucent = NO;
}

- (NSString *) tableView:(UITableView *) tableView titleForHeaderInSection:(NSInteger) section {
    if (section == SubjectInformationSection)
        return @"Subject Name";
    if (section == IssuerInformationSection)
        return @"Issuer Name";
    if (section == CertificateInformationSection)
        return @"Certificate Information";
    return nil;
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *) tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == SubjectInformationSection)
        return 7;
    if (section == IssuerInformationSection)
        return 7;
    if (section == CertificateInformationSection)
        return 7;
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    if (indexPath.section == SubjectInformationSection) {
        CertificateItemRow *item = _subjectInformation[indexPath.row];
        cell.textLabel.text = item.itemName;
        cell.detailTextLabel.text = item.itemDescription;
        
    } else if (indexPath.section == IssuerInformationSection) {

        CertificateItemRow *item = _issuerInformation[indexPath.row];
        cell.textLabel.text = item.itemName;
        cell.detailTextLabel.text = item.itemDescription;
        
    } else if (indexPath.section == CertificateInformationSection) {
        CertificateItemRow *item = _certificateInformation[indexPath.row];
        cell.textLabel.text = item.itemName;
        cell.detailTextLabel.text = item.itemDescription;
        
    }

    return cell;
}

@end
