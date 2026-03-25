<?php

namespace App\Tests\Crudit;

use App\Entity\User;
use DateTime;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\ORM\EntityManagerInterface;
use Doctrine\ORM\Mapping\ClassMetadata;
use ReflectionClass;
use ReflectionMethod;
use Symfony\Bundle\FrameworkBundle\Test\KernelTestCase;

/**
 * Class AllEntityTest
 * @package App\Tests\Entity
 */
class EntityTest extends KernelTestCase
{
    protected EntityManagerInterface $em;

    public function setUp(): void
    {
        $kernel = static::bootKernel();
        $this->em = $kernel->getContainer()
            ->get('doctrine')
            ->getManager();
    }

    public function isIgnore($pathMethod): bool
    {
        return in_array($pathMethod, [
            User::class . "::roles",
        ]);
    }

    public function testAll()
    {
        foreach ($this->em->getMetadataFactory()->getAllMetadata() as $metaDataEntity) {
            /* @var ClassMetadata $metaDataEntity */
            if (
                !$metaDataEntity->getReflectionClass()->isAbstract()
                && strstr($metaDataEntity->getName(), 'App')
            ) {
                $this->checkEntity($metaDataEntity);
            }
        }
    }

    private function checkEntity(ClassMetadata $metaData)
    {
        $entity = $metaData->getReflectionClass()->newInstance();
        $repo = $this->em->getRepository($metaData->getName());
        self::assertNotNull($repo);
        $this->checkIdentifiers($metaData, $entity);
        $this->checkFields($metaData, $entity);
        $this->checkAssociations($metaData, $entity);
        $this->assertToString($metaData, $entity);
    }

    private function assertToString(ClassMetadata $metaData, $entity)
    {
        if ($metaData->getReflectionClass()->hasMethod('__toString')) {
            self::assertNotNull((string)$entity);
        }
    }

    private function checkIdentifiers(ClassMetadata $metaData, $entity)
    {
        foreach ($metaData->getIdentifier() as $identifier) {
            if (!$this->isIgnore($metaData->getName() . '::' . $identifier)) {
                $gmethod = $this->getMethodByField($metaData->getReflectionClass(), $identifier);
                if ($gmethod) {
                    self::assertNull($gmethod->invoke($entity));
                }
            }
        }
    }

    private function checkFields(ClassMetadata $metaData, $entity)
    {
        foreach ($metaData->getFieldNames() as $name) {
            $mapping = $metaData->getFieldMapping($name);
            if (!$this->isIgnore($metaData->getName() . '::' . $mapping['fieldName'])) {
                $smethod = $this->getMethodByField($metaData->getReflectionClass(), $mapping['fieldName'], 'SET');
                $gmethod = $this->getMethodByField($metaData->getReflectionClass(), $mapping['fieldName']);
                if ($smethod && $gmethod) {
                    $value = $this->getValueByType($mapping['type']);
                    $smethod->invoke($entity, $value);
                    self::assertEquals(
                        $gmethod->invoke($entity),
                        $value,
                        $metaData->getName() . '::' . $mapping['fieldName']
                    );
                }
            }
        }
    }

    public function checkAssociations(ClassMetadata $metaData, $entity)
    {
        foreach ($metaData->getAssociationNames() as $associationName) {
            $mapping = $metaData->getAssociationMapping($associationName);
            if (!$this->isIgnore($metaData->getName() . '::' . $mapping['fieldName'])) {
                if ($metaData->isSingleValuedAssociation($associationName)) {
                    $this->checkSingleAssociation($metaData, $entity, $associationName);
                } else {
                    $this->checkMultiAssociation($metaData, $entity, $associationName);
                }
            }
        }
    }

    private function checkSingleAssociation(ClassMetadata $metaData, $entity, $associationName)
    {
        $mapping = $metaData->getAssociationMapping($associationName);
        $smethod = $this->getMethodByField($metaData->getReflectionClass(), $associationName, 'SET');
        $gmethod = $this->getMethodByField($metaData->getReflectionClass(), $associationName);
        if ($smethod && $gmethod) {
            $value = $this->em->getClassMetadata($mapping['targetEntity'])->getReflectionClass()->newInstance();
            $smethod->invoke($entity, $value);
            self::assertEquals(
                get_class($gmethod->invoke($entity)),
                $mapping['targetEntity'],
                $metaData->getName() . '::' . $mapping['fieldName']
            );
        }
    }

    private function checkMultiAssociation(ClassMetadata $metaData, $entity, $associationName)
    {
        $mapping = $metaData->getAssociationMapping($associationName);
        $smethod = $this->getMethodByField($metaData->getReflectionClass(), $associationName, 'SET');
        $amethod = $this->getMethodByField($metaData->getReflectionClass(), $associationName, 'ADD');
        $gmethod = $this->getMethodByField($metaData->getReflectionClass(), $associationName);
        $rmethod = $this->getMethodByField($metaData->getReflectionClass(), $associationName, 'REMOVE');
        if ($amethod && $gmethod) {
            $value = $this->em->getClassMetadata($mapping['targetEntity'])->getReflectionClass()->newInstance();
            $amethod->invoke($entity, $value);
            $collection = $gmethod->invoke($entity);
            $this->checkCollection($metaData, $mapping, $collection);
            if ($rmethod) {
                $rmethod->invoke($entity, $value);
                $collection = $gmethod->invoke($entity);
                self::assertEquals(count($collection), 0, $metaData->getName() . '::' . $mapping['fieldName']);
            }
            if ($smethod) {
                $smethod->invoke($entity, new ArrayCollection([$value]));
                $this->checkCollection($metaData, $mapping, $gmethod->invoke($entity));
            }
        }
    }

    private function checkCollection(ClassMetadata $metaData, $mapping, $collections)
    {
        self::assertEquals(
            get_class($collections),
            ArrayCollection::class,
            $metaData->getName() . '::' . $mapping['fieldName']
        );
        self::assertEquals(
            count($collections),
            1,
            $metaData->getName() . '::' . $mapping['fieldName']
        );
        self::assertEquals(
            get_class($collections[0]),
            $mapping['targetEntity'],
            $metaData->getName() . '::' . $mapping['fieldName']
        );
    }

    private function getValueByType(string $type)
    {
        return [
            'string' => 'toto',
            'text' => 'text',
            'integer' => 1,
            'boolean' => true,
            'date' => new DateTime(),
            'datetime' => new DateTime(),
            'datetime_immutable' => new \DateTimeImmutable(),
            'json_array' => [],
            'json' => [],
            'decimal' => 1,
            'float' => 1.2,
            'smallint' => 1,
            'bigint' => 1,
            'time' => new DateTime(),
            'array' => []
        ][$type] ?? 'default' . $type;
    }

    private function getMethodByField(
        ReflectionClass $reflectionClass,
        string $name,
        $mode = 'GET'
    ): ?ReflectionMethod {
        $return = null;
        if ($mode === 'GET') {
            $return = $this->getMethod($reflectionClass, [$name, 'get' . $name, 'is' . $name, 'has' . $name]);
        } elseif ($mode === 'SET') {
            $return = $this->getMethod($reflectionClass, ['set' . $name]);
        } elseif ($mode === 'ADD') {
            $return = $this->getMethod($reflectionClass, ['add' . substr($name, 0, -1)]);
        } elseif ($mode === 'REMOVE') {
            $return = $this->getMethod($reflectionClass, ['remove' . substr($name, 0, -1)]);
        }

        return $return;
    }

    private function getMethod(ReflectionClass $reflectionClass, array $methods): ?ReflectionMethod
    {
        foreach ($methods as $method) {
            if ($reflectionClass->hasMethod($method)) {
                $method = $reflectionClass->getMethod($method);
                if ($method->isPublic()) {
                    return $method;
                }
            }
        }

        return null;
    }
}
