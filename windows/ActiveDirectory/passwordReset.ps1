$lname = read-host "Last Name:"
$fname = read-host "First Name:"

$userdata = get-aduser -filter {surname -like $lname -and givenname -like $fname} - Properties * | select-object samaccountname, mail, givenname, surname, enabled,lockedout, name

### Handler for multiple accounts with the same fname lname
if ($userdata.count -gt 1){
  $x = 0
  foreach($i in $userdata){
    write-output "$x - $(i.samaccountname) - $(i.name)"
    $x++
  }
  $user = read-host "Multiple users detected. select the correct user"
  $userdata = get-aduser -Identity $($userdata[$user].samaccountname) -Properties * | select-object samaccountname, mail, givenname, surname, enabled, lockedout, name
}
### admin has to validate the user
$userdata
$user = read-host "Is tis the correct user? (y/n)"


### Store account details
if ($user.tolower() -eq "y"){
  $samaccountname = $userdata.samaccountname
  $lockedout = $userdata.lockedout
  $enabled = $userdata.enabled
  $email = $userdata.mail
  $fullname = $userdata.name
}

### Generate the password
$pwstring = ""
$letters = @("a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z")
$chars = @("!","@","#","$","%","^","&","*")
while($pwloopcount -lt 4){
  $pwstring +=$letters[(get-random(0..25))]
  $pwstring += ($letters[(get-random(0..25))]).toupper()
  $pwstring += get-random(0..9)
  $pwstring +=$chars[(get-random(0..7))]
  $pwloopcount--
}
$rndpwd = ""
$pwarray = (($string.tochararray()) | sort-object {get-random})
foreach ($i in $pwarray){
  $rndpwd += $i
}
$securepw = convertto-decurestring $rndpwd -AsPlainText -force

write-output "Setting new password, forcing change at login"
set-adaccountpassword -Identity $samaccountname -newpassword $securepw
set-aduser -identity $samaccountname -cahangepasswordatlogon $true
write-output "Checking if user is locked out"
if ($lockedout){
  write-output "Account locked out.... unlocking"
  unlock-adaccount -indentity $samaccountname
}
write-output "checking if account is enabled"
if (!$enabled){
  write-output "Account is disabled... enabling"
}

$mailserver = ""  #####Enter mailserver here
$admin = "noreply@admin.org   ####enter admin distro here
write-output "Sending new password and account details"
send-mailmessage -smtpServer $mailserver -to $email -from $admin --subject "Username" -body "
  Your account has been unlocked. Do NOT reply to this email.
  
  account: $samaccountname
  
  You are required to change your password at next login
  "
  write-output "Sending new password and account details"
send-mailmessage -smtpServer $mailserver -to $email -from $admin --subject "Password" -body "
  Your account has been unlocked. This is the password email.
  
  password: $rndpwd
  
  You are required to change your password at next login
  "
  
  
write-output "Updating password change logfile"
$dtg = get-date
$changeby = whoami
write-output "$dtg - $changeby reset $samaccountname" | outfile -append "C:\admin\resetlog.txt"

#clear memory
$rndpwd = $null
$securepw = $null

