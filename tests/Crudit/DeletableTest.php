<?php

namespace App\Tests\Crudit;

use Doctrine\ORM\EntityManagerInterface;
use Error;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;

class DeletableTest extends KernelTestCase
{
    public function testIfDeleteCascadeCorrect(): void
    {
        $em = $this->getContainer()->get(EntityManagerInterface::class);
        $metas = $em->getMetadataFactory()->getAllMetadata();
        foreach ($metas as $meta) {
            if (str_starts_with($meta->name, 'App')) { // only handle app entities
                try {
                    $obj = new $meta->name();

                    foreach ($meta->associationMappings as $assoc) {
                        if (!$assoc['isCascadeRemove'] && !$assoc['isOwningSide']) {
                            if (str_starts_with($assoc["targetEntity"], 'App')) { // only handle app entities
                                $ass_obj = new $assoc["targetEntity"]();
                                $addMethod = "add" . ucfirst(substr($assoc['fieldName'], 0, -1));
                                if (method_exists($obj, $addMethod)) {
                                    $obj->$addMethod($ass_obj);

                                    if (method_exists($obj, "canDelete")) {
                                        $this->assertNotTrue(
                                            $obj->canDelete(),
                                            "canDelete faux pour " . $meta->name . "->" . $assoc['fieldName']
                                        );
                                    } else {
                                        $this->addWarning("canDelete non implémenté dans " . $meta->name);
                                    }
                                }
                            }
                        }
                    }
                } catch (Error $error) {
                    print($error);
                }
            }
        }
    }
}
