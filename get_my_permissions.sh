#!/bin/bash
# This script retrieves the list of Azure subscriptions and the roles assigned to the signed-in user in each subscription.
# Usage: ./get_my_permissions.sh
# 
# Output example:
# # Subscription: MySubscription (12345678-1234-1234-1234-123456789012)
# #   - Owner
# #   - Contributor

subscriptions=$(az account list --query "[].{name:name, id:id}" -o json)

for row in $(echo "${subscriptions}" | jq -r '.[] | @base64'); do
    _jq() {
        echo ${row} | base64 --decode | jq -r ${1}
    }

    sub_name=$(_jq '.name')
    sub_id=$(_jq '.id')

    echo "Subscription: $sub_name ($sub_id)"

    az account set --subscription "$sub_id"

    az role assignment list --query "[?principalName=='$(az ad signed-in-user show --query userPrincipalName -o tsv)'].{role:roleDefinitionName}" -o tsv | while read role; do
        echo "  - $role"
    done
done

