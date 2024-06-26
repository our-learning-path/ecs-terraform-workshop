package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/joho/godotenv"
	"github.com/stretchr/testify/require"
)

func TestEcrIsCreatedWithDefaultValues(t *testing.T) {
	t.Parallel()
	godotenv.Load()
	repositoryName := "test_ecr_repo"
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform/modules/ecr_registry",
		Vars: map[string]interface{}{
			"repository_name": repositoryName,
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)
	actualRepositoryName := terraform.Output(t, terraformOptions, "repository_name")
	require.Equal(t, repositoryName, actualRepositoryName)

	repositoryURL := terraform.Output(t, terraformOptions, "repository_url")
	require.NotEmpty(t, repositoryURL)
}
