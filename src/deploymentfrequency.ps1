# TODO 
# - There are tons of bugs
# - no versioning/tags/releases - (just use @main tag for now)
# - minimal error handling
# - some rounding errors
# - some questionable decisions made for the output. 

Param(
    [string] $ownerRepo,
    [string] $workflows,
    [string] $branch,
    [Int32] $numberOfDays
)

#==========================================
#Input processing
$ownerRepoArray = $ownerRepo -split '/'
$owner = $ownerRepoArray[0]
$repo = $ownerRepoArray[1]
Write-Output "Owner/Repo: $owner/$repo"
$workflowsArray = $workflows -split ','
Write-Output "Workflows: $($workflowsArray[0])"
Write-Output "Branch: $branch"
$numberOfDays = $numberOfDays        
Write-Output "Number of days: $numberOfDays"

#==========================================
#Get workflow definitions from github
$uri = "https://api.github.com/repos/$owner/$repo/actions/workflows"
$workflowsResponse = Invoke-RestMethod -Uri $uri -ContentType application/json -Method Get -ErrorAction Stop

#==========================================
#Extract workflow ids from the definitions, using the array of names. Number of Ids should == number of workflow names
$workflowIds = [System.Collections.ArrayList]@()
Foreach ($workflow in $workflowsResponse.workflows){

    Foreach ($arrayItem in $workflowsArray){
        if ($workflow.name -eq $arrayItem)
        {
            #Write-Output "'$($workflow.name)' matched with $arrayItem"
            $result = $workflowIds.Add($workflow.id)
            if ($result -lt 0)
            {
                Write-Output "unexpected result"
            }
        }
        else 
        {
            #Write-Output "'$($workflow.name)' DID NOT match with $arrayItem"
        }
    }
}

#==========================================
#Filter out workflows that were successful. Measure the number by date/day. Aggegate workflows together
$dateList = @()

#For each workflow id, get the last 100 workflows from github
Foreach ($workflowId in $workflowIds){
    #Get workflow definitions from github
    $uri2 = "https://api.github.com/repos/$owner/$repo/actions/workflows/$workflowId/runs?per_page=100"
    $workflowRunsResponse = Invoke-RestMethod -Uri $uri2 -ContentType application/json -Method Get -ErrorAction Stop

    $buildTotal = 0
    Foreach ($run in $workflowRunsResponse.workflow_runs){
        #Count workflows that are completed, on the target branch, and were created within the day range we are looking at
        if ($run.status -eq "completed" -and $run.head_branch -eq $branch -and $run.created_at -gt (Get-Date).AddDays(-$numberOfDays))
        {
            #Write-Output "Adding item with status $($run.status), branch $($run.head_branch), created at $($run.created_at), compared to $((Get-Date).AddDays(-$numberOfDays))"
            $buildTotal++       
            #get the workflow start and end time            
            $dateList += New-Object PSObject -Property @{start_datetime=$run.created_at;end_datetime=$run.updated_at}     
        }
    }
}


#==========================================
#Calculate deployments per day
$deploymentsPerDay = 0

if ($dateList.Count -gt 0 -and $numberOfDays -gt 0)
{
    $deploymentsPerDay = $dateList.Count / $numberOfDays
}


#==========================================
#output result
$dailyDeployment = 1
$weeklyDeployment = 1 / 7
$monthlyDeployment = 1 / 30
$everySixMonthsDeployment = 1 / (6 * 30) #//Every 6 months
$yearlyDeployment = 1 / 365

#Calculate rating 
$rating = ""
if ($deploymentsPerDay -le 0)
{
    $rating = "None"
}
elseif ($deploymentsPerDay -ge $dailyDeployment)
{
    $rating = "Elite"
}
elseif ($deploymentsPerDay -le $dailyDeployment -and $deploymentsPerDay -ge $monthlyDeployment)
{
    $rating = "High"
}
elseif (deploymentsPerDay -le $monthlyDeployment -and $deploymentsPerDay -ge $everySixMonthsDeployment)
{
    $rating = "Medium"
}
elseif ($deploymentsPerDay -le $everySixMonthsDeployment)
{
    $rating = "Low"
}

#Calculate metric and unit
if ($deploymentsPerDay -gt $dailyDeployment) 
{
    $displayMetric = $deploymentsPerDay
    $displayUnit = "per day"
}
elseif ($deploymentsPerDay -le $dailyDeployment -and $deploymentsPerDay -ge $weeklyDeployment)
{
    $displayMetric = $deploymentsPerDay * 7
    $displayUnit = "times per week"
}
elseif ($deploymentsPerDay -lt $weeklyDeployment -and $deploymentsPerDay -ge $monthlyDeployment)
{
    $displayMetric = $deploymentsPerDay * 30
    $displayUnit = "times per month"
}
elseif ($deploymentsPerDay -lt $monthlyDeployment -and $deploymentsPerDay -gt $yearlyDeployment)
{
    $displayMetric = $deploymentsPerDay * 30
    $displayUnit = "times per month"
}
elseif ($deploymentsPerDay -le $yearlyDeployment)
{
    $displayMetric = $deploymentsPerDay * 365
    $displayUnit = "times per year"
}

Write-Output "Deployment frequency over last $numberOfDays days, is $displayMetric $displayUnit, with a DORA rating of '$rating'"