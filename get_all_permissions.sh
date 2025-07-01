#!/bin/bash

# Get all subscriptions
subscriptions=$(az account list --query "[].{id:id, name:name}" -o json)

# Get the current user's object ID
user_id=$(az ad signed-in-user show --query id -o tsv)

echo "Fetching permissions for user: $user_id"

# Loop through each subscription
for row in $(echo "${subscriptions}" | jq -r '.[] | @base64'); do
    _jq() {
     echo ${row} | base64 --decode | jq -r ${1}
    }

    sub_id=$(_jq '.id')
    sub_name=$(_jq '.name')

    echo "--------------------------------------------------"
    echo "Subscription: $sub_name ($sub_id)"
    echo "--------------------------------------------------"

    # Set the current subscription
    az account set --subscription "$sub_id"

    # Get subscription-level role assignments for the user
    sub_roles=$(az role assignment list --assignee $user_id --scope "/subscriptions/$sub_id" --query "[].roleDefinitionName" -o tsv)

    if [ -n "$sub_roles" ]; then
        echo "  Subscription Level Roles:"
        while IFS= read -r role; do
            echo "    - Role: $role"
        done <<< "$sub_roles"
        echo "--------------------------------------------------"
    fi

    # Get all resource groups in the subscription
    resource_groups=$(az group list --query "[].name" -o tsv)

    # Initialize a list for resource groups with no roles
    no_roles_rg_list=""

    # Loop through each resource group
    for rg in $resource_groups; do
        # Get the role assignments for the user on the resource group
        roles=$(az role assignment list --assignee $user_id --resource-group $rg --query "[].roleDefinitionName" -o tsv)

        if [ -n "$roles" ]; then
            echo "  Resource Group: $rg"
            while IFS= read -r role; do
                echo "    - Role: $role"
            done <<< "$roles"
        else
            # Add the resource group to the list of RGs with no roles
            if [ -z "$no_roles_rg_list" ]; then
                no_roles_rg_list="$rg"
            else
                no_roles_rg_list="$no_roles_rg_list, $rg"
            fi
        fi
    done

    # Print the list of resource groups with no roles at the end
    if [ -n "$no_roles_rg_list" ]; then
        echo ""
        echo "  Resource groups with no assigned roles:"
        echo "    $no_roles_rg_list"
    fi
done
