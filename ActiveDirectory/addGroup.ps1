function addToGroup{
  param($group)
  
  $list = get-content "C:\admin\userlist.txt"
  write-output "Group Set as $group"
  write-output "1 - firstname lastname (Default)"
  write-output "2 - lastname firstname"
  $format = read-host "How is the list formatted?"
  $dtg = (get-date).addhours(-4)
  $admin = whoami
  foreach($i in $list){
    $i = $i.trim()
    if($format -eq 2){
      $lname = ($i.split(" "))[0]
      $fname = ($i.split(" "))[1]
    }
    else{
      $lname = ($i.split(" "))[1]
      $fname = ($i.split(" "))[0]
    }
    
    $user = get-aduser -filter {surname -like $lname -and givenname -like $fname}
    
    if($user.count -gt 1){
      $x = 0
      foreach($j in $user){
        write-output "$x - $($j.samaccountname) - $($j.name)"
        $x++
      }
      $correct = read-host "Multiple users detected. Select the correct user"
      $user = get-aduser -Identity $(user[$correct].samaccountname)
    }
    
    if (!$user){
      write-output "$fname $lname not found"
      write-output "$dtg EST - ERROR - $admin attempted to add $fname $lname to $group" | out-file -append "c:\admin\ad_group_error.txt"
    }
    else{
      get-adgroup -filter {name -eq $group} | add-adgroupmember -members $user
      write-output "$dtg EST - $admin added $user to $group" | out-file -append "c:\admin\ad_group_log.txt"
    }
  }
}
