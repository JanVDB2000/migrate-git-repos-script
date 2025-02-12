#!/bin/bash

# Instellingen
GITHUB_ORG="" # Je GitHub organisatie of gebruikersnaam
GITHUB_TOKEN="" # Vervang dit door je GitHub Personal Access Token
REPO_LIST="repos.txt" # Bestand met repo-namen (één per regel)

# Controleer of het repo-lijstbestand bestaat
if [ ! -f "$REPO_LIST" ]; then
    echo "Fout: Bestand '$REPO_LIST' niet gevonden!"
    exit 1
fi

# Loop door de lijst met repository URL's
while IFS= read -r REPO_URL; do
    # Sla lege regels over
    if [[ -z "$REPO_URL" ]]; then
        continue
    fi

    # Haal de reponaam op uit de volledige URL (verwijder evt. .git aan het eind)
    REPO_NAME=$(basename "$REPO_URL" .git)
    echo "Migreren van $REPO_NAME..."

    # Stap 1: Controleer of de GitHub-repo al bestaat
    CHECK_REPO=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_ORG/$REPO_NAME")

    if [[ "$CHECK_REPO" -eq 404 ]]; then
        echo "Repository $REPO_NAME bestaat nog niet op GitHub. Aanmaken..."
        
        # Stap 2: Maak de repository aan op GitHub (standaard privé; pas zonodig de opties aan)
        curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
            -d "{\"name\": \"$REPO_NAME\", \"private\": true}" \
            "https://api.github.com/orgs/$GITHUB_ORG/repos"

        echo "Repository $REPO_NAME aangemaakt op GitHub."
    else
        echo "Repository $REPO_NAME bestaat al op GitHub, overslaan."
    fi

    # Stap 3: Clone de repo van de oude server via de volledige URL
    git clone --mirror "$REPO_URL"

    # Ga naar de gekloonde repo-directory
    cd "$REPO_NAME.git" || { echo "Fout bij openen van $REPO_NAME.git"; exit 1; }

    # Stap 4: Nieuwe remote instellen naar GitHub
    git remote remove origin
    git remote add origin "git@github.com:$GITHUB_ORG/$REPO_NAME.git"

    # Stap 5: Push naar GitHub met alle branches en tags
    git push --mirror origin

    # Stap 6: Ga terug naar de hoofddirectory en opruimen
    cd ..
    rm -rf "$REPO_NAME.git"

    echo "$REPO_NAME succesvol gemigreerd naar GitHub."
done < "$REPO_LIST"

echo "Alle repositories zijn gemigreerd!"
