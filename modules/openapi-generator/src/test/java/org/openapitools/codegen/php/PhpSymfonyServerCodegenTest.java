/*
 * Copyright 2018 OpenAPI-Generator Contributors (https://openapi-generator.tech)
 * Copyright 2018 SmartBear Software
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.openapitools.codegen.php;

import org.openapitools.codegen.ClientOptInput;
import org.openapitools.codegen.CodegenConstants;
import org.openapitools.codegen.DefaultGenerator;
import org.openapitools.codegen.TestUtils;
import org.openapitools.codegen.config.CodegenConfigurator;
import org.openapitools.codegen.languages.AbstractPhpCodegen;
import org.openapitools.codegen.languages.PhpSymfonyServerCodegen;
import org.testng.Assert;
import org.testng.SkipException;
import org.testng.annotations.Test;

import java.io.File;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.regex.Pattern;


public class PhpSymfonyServerCodegenTest {

    @Test
    public void testInitialConfigValues() throws Exception {
        final PhpSymfonyServerCodegen codegen = new PhpSymfonyServerCodegen();
        codegen.processOpts();

        Assert.assertEquals(codegen.additionalProperties().get(CodegenConstants.HIDE_GENERATION_TIMESTAMP), Boolean.TRUE);
        Assert.assertEquals(codegen.isHideGenerationTimestamp(), true);
    }

    @Test
    public void testSettersForConfigValues() throws Exception {
        final PhpSymfonyServerCodegen codegen = new PhpSymfonyServerCodegen();
        codegen.setHideGenerationTimestamp(false);
        codegen.processOpts();

        Assert.assertEquals(codegen.additionalProperties().get(CodegenConstants.HIDE_GENERATION_TIMESTAMP), Boolean.FALSE);
        Assert.assertEquals(codegen.isHideGenerationTimestamp(), false);
    }

    @Test
    public void testAdditionalPropertiesPutForConfigValues() throws Exception {
        final PhpSymfonyServerCodegen codegen = new PhpSymfonyServerCodegen();
        codegen.additionalProperties().put(CodegenConstants.HIDE_GENERATION_TIMESTAMP, false);
        codegen.processOpts();

        Assert.assertEquals(codegen.additionalProperties().get(CodegenConstants.HIDE_GENERATION_TIMESTAMP), Boolean.FALSE);
        Assert.assertEquals(codegen.isHideGenerationTimestamp(), false);
    }

    @Test
    public void testGeneratePing() throws Exception {
        Map<String, Object> properties = new HashMap<>();

        File output = Files.createTempDirectory("test").toFile();

        final CodegenConfigurator configurator = new CodegenConfigurator()
                .setGeneratorName("php-symfony")
                .setAdditionalProperties(properties)
                .setInputSpec("src/test/resources/3_0/ping.yaml")
                .setOutputDir(output.getAbsolutePath().replace("\\", "/"));

        final ClientOptInput clientOptInput = configurator.toClientOptInput();
        DefaultGenerator generator = new DefaultGenerator();
        List<File> files = generator.opts(clientOptInput).generate();

        Assert.assertEquals(files.size(), 33);
        TestUtils.ensureContainsFile(files, output, ".coveralls.yml");
        TestUtils.ensureContainsFile(files, output, ".gitignore");
        TestUtils.ensureContainsFile(files, output, ".openapi-generator-ignore");
        TestUtils.ensureContainsFile(files, output, ".openapi-generator/FILES");
        TestUtils.ensureContainsFile(files, output, ".openapi-generator/VERSION");
        TestUtils.ensureContainsFile(files, output, ".php_cs.dist");
        TestUtils.ensureContainsFile(files, output, ".travis.yml");
        TestUtils.ensureContainsFile(files, output, "autoload.php");
        TestUtils.ensureContainsFile(files, output, "composer.json");
        TestUtils.ensureContainsFile(files, output, "git_push.sh");
        TestUtils.ensureContainsFile(files, output, "phpunit.xml.dist");
        TestUtils.ensureContainsFile(files, output, "README.md");
        TestUtils.ensureContainsFile(files, output, "Api/ApiServer.php");
        TestUtils.ensureContainsFile(files, output, "Api/DefaultApiInterface.php");
        TestUtils.ensureContainsFile(files, output, "Controller/Controller.php");
        TestUtils.ensureContainsFile(files, output, "Controller/DefaultController.php");
        TestUtils.ensureContainsFile(files, output, "DependencyInjection/Compiler/OpenAPIServerApiPass.php");
        TestUtils.ensureContainsFile(files, output, "DependencyInjection/OpenAPIServerExtension.php");
        TestUtils.ensureContainsFile(files, output, "docs/Api/DefaultApiInterface.md");
        TestUtils.ensureContainsFile(files, output, "OpenAPIServerBundle.php");
        TestUtils.ensureContainsFile(files, output, "Resources/config/routing.yaml");
        TestUtils.ensureContainsFile(files, output, "Resources/config/services.yaml");
        TestUtils.ensureContainsFile(files, output, "Service/JmsSerializer.php");
        TestUtils.ensureContainsFile(files, output, "Service/SerializerInterface.php");
        TestUtils.ensureContainsFile(files, output, "Service/StrictJsonDeserializationVisitor.php");
        TestUtils.ensureContainsFile(files, output, "Service/StrictJsonDeserializationVisitorFactory.php");
        TestUtils.ensureContainsFile(files, output, "Service/SymfonyValidator.php");
        TestUtils.ensureContainsFile(files, output, "Service/TypeMismatchException.php");
        TestUtils.ensureContainsFile(files, output, "Service/ValidatorInterface.php");
        TestUtils.ensureContainsFile(files, output, "Tests/Api/DefaultApiInterfaceTest.php");
        TestUtils.ensureContainsFile(files, output, "Tests/AppKernel.php");
        TestUtils.ensureContainsFile(files, output, "Tests/Controller/ControllerTest.php");
        TestUtils.ensureContainsFile(files, output, "Tests/test_config.yaml");

        output.deleteOnExit();
    }

    @Test
    public void testGeneratePingWithDifferentSourceDirectory() throws Exception {
        Map<String, Object> properties = new HashMap<>();
        properties.put(AbstractPhpCodegen.SRC_BASE_PATH, "src");

        File output = Files.createTempDirectory("test").toFile();

        final CodegenConfigurator configurator = new CodegenConfigurator()
                .setGeneratorName("php-symfony")
                .setAdditionalProperties(properties)
                .setInputSpec("src/test/resources/3_0/ping.yaml")
                .setOutputDir(output.getAbsolutePath().replace("\\", "/"));

        final ClientOptInput clientOptInput = configurator.toClientOptInput();
        DefaultGenerator generator = new DefaultGenerator();
        List<File> files = generator.opts(clientOptInput).generate();

        Assert.assertEquals(files.size(), 33);
        TestUtils.ensureContainsFile(files, output, ".coveralls.yml");
        TestUtils.ensureContainsFile(files, output, ".gitignore");
        TestUtils.ensureContainsFile(files, output, ".openapi-generator-ignore");
        TestUtils.ensureContainsFile(files, output, ".openapi-generator/FILES");
        TestUtils.ensureContainsFile(files, output, ".openapi-generator/VERSION");
        TestUtils.ensureContainsFile(files, output, ".php_cs.dist");
        TestUtils.ensureContainsFile(files, output, ".travis.yml");
        TestUtils.ensureContainsFile(files, output, "autoload.php");
        TestUtils.ensureContainsFile(files, output, "composer.json");
        TestUtils.ensureContainsFile(files, output, "git_push.sh");
        TestUtils.ensureContainsFile(files, output, "phpunit.xml.dist");
        TestUtils.ensureContainsFile(files, output, "README.md");
        TestUtils.ensureContainsFile(files, output, "docs/Api/DefaultApiInterface.md");
        TestUtils.ensureContainsFile(files, output, "src/Api/ApiServer.php");
        TestUtils.ensureContainsFile(files, output, "src/Api/DefaultApiInterface.php");
        TestUtils.ensureContainsFile(files, output, "src/Controller/Controller.php");
        TestUtils.ensureContainsFile(files, output, "src/Controller/DefaultController.php");
        TestUtils.ensureContainsFile(files, output, "src/DependencyInjection/Compiler/OpenAPIServerApiPass.php");
        TestUtils.ensureContainsFile(files, output, "src/DependencyInjection/OpenAPIServerExtension.php");
        TestUtils.ensureContainsFile(files, output, "src/OpenAPIServerBundle.php");
        TestUtils.ensureContainsFile(files, output, "src/Resources/config/routing.yaml");
        TestUtils.ensureContainsFile(files, output, "src/Resources/config/services.yaml");
        TestUtils.ensureContainsFile(files, output, "src/Service/JmsSerializer.php");
        TestUtils.ensureContainsFile(files, output, "src/Service/SerializerInterface.php");
        TestUtils.ensureContainsFile(files, output, "src/Service/StrictJsonDeserializationVisitor.php");
        TestUtils.ensureContainsFile(files, output, "src/Service/StrictJsonDeserializationVisitorFactory.php");
        TestUtils.ensureContainsFile(files, output, "src/Service/SymfonyValidator.php");
        TestUtils.ensureContainsFile(files, output, "src/Service/TypeMismatchException.php");
        TestUtils.ensureContainsFile(files, output, "src/Service/ValidatorInterface.php");
        TestUtils.ensureContainsFile(files, output, "src/Tests/Api/DefaultApiInterfaceTest.php");
        TestUtils.ensureContainsFile(files, output, "src/Tests/AppKernel.php");
        TestUtils.ensureContainsFile(files, output, "src/Tests/Controller/ControllerTest.php");
        TestUtils.ensureContainsFile(files, output, "src/Tests/test_config.yaml");

        output.deleteOnExit();
    }

    /**
     * OpenAPI 3.1 + dotted schema keys + {@code components.parameters} {@code $ref}: enum-ref query
     * parameters must use a short model class name in {@code DefaultApiInterface} (aligned with
     * {@code use} imports), not a bogus flattened namespace token.
     * <p>
     * Also verifies PHPDoc {@code @param} uses the same short name (not {@code \\FQCN}) and, when
     * {@code php} is on {@code PATH}, that {@code php -l} accepts the generated file (valid syntax).
     */
    @Test
    public void testPetstoreDottedEnumRefQueryParameterUsesShortClassInApiInterface() throws Exception {
        Map<String, Object> properties = new HashMap<>();
        properties.put("invokerPackage", "Org\\OpenAPITools\\Petstore");

        File output = Files.createTempDirectory("test").toFile();

        final CodegenConfigurator configurator = new CodegenConfigurator()
                .setGeneratorName("php-symfony")
                .setAdditionalProperties(properties)
                .setInputSpec("src/test/resources/3_1/php-symfony/petstore-dotted-enum-ref-query-param-component.yaml")
                .setOutputDir(output.getAbsolutePath().replace("\\", "/"));

        final ClientOptInput clientOptInput = configurator.toClientOptInput();
        DefaultGenerator generator = new DefaultGenerator();
        List<File> files = generator.opts(clientOptInput).generate();

        File apiInterfaceFile = files.stream()
                .filter(f -> "DefaultApiInterface.php".equals(f.getName()) && f.getPath().contains("Api" + File.separator))
                .findFirst()
                .orElseThrow(() -> new AssertionError("DefaultApiInterface.php not generated"));

        String apiContent = Files.readString(apiInterfaceFile.toPath(), StandardCharsets.UTF_8);
        Assert.assertFalse(
                apiContent.contains("OrgOpenAPIToolsPetstoreModel"),
                "Must not emit flattened invoker+model token in interface");
        Assert.assertTrue(
                apiContent.contains("use Org\\OpenAPITools\\Petstore\\Model\\PetModelPetStatus;"),
                "Expected enum model import");
        Assert.assertTrue(
                apiContent.contains("?PetModelPetStatus $status"),
                "Expected enum ref query param to use short class in type hint");
        Assert.assertTrue(
                Pattern.compile("@param\\s+PetModelPetStatus\\|null\\s+\\$status\\b").matcher(apiContent).find(),
                "PHPDoc @param should use short PetModelPetStatus|null (consistent with use import)");
        Assert.assertFalse(
                apiContent.contains("?\\Org\\OpenAPITools\\Petstore\\Model\\PetModelPetStatus $status"),
                "Signature must not use leading-backslash FQCN when a matching use import exists");
        Assert.assertFalse(
                apiContent.contains("@param  \\Org\\"),
                "PHPDoc @param must not use leading-backslash FQCN for enum ref");

        assertGeneratedPhpSyntaxValid(apiInterfaceFile);

        output.deleteOnExit();
    }

    /**
     * Runs {@code php -l} on the file. Skips if {@code php} is not available (optional toolchain).
     */
    private static void assertGeneratedPhpSyntaxValid(File phpFile) throws Exception {
        ProcessBuilder pb = new ProcessBuilder("php", "-l", phpFile.getAbsolutePath());
        pb.redirectErrorStream(true);
        final Process p;
        try {
            p = pb.start();
        } catch (IOException e) {
            throw new SkipException("php not available on PATH, skipping syntax check: " + e.getMessage());
        }
        Assert.assertTrue(p.waitFor(30, TimeUnit.SECONDS), "php -l timed out");
        String out = new String(p.getInputStream().readAllBytes(), StandardCharsets.UTF_8).trim();
        Assert.assertEquals(p.exitValue(), 0, "php -l must accept generated interface: " + out);
    }
}
