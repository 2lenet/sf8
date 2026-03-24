<?php

namespace App\Entity;

use Config;
use Doctrine\Persistence\ManagerRegistry;
use Lle\ConfigBundle\Repository\AbstractConfigRepository;
use Lle\ConfigBundle\Service\CacheManager;

/**
 * @method Config|null find($id, $lockMode = null, $lockVersion = null)
 * @method Config|null findOneBy(array $criteria, array $orderBy = null)
 * @method Config[]    findAll()
 * @method Config[]    findBy(array $criteria, array $orderBy = null, $limit = null, $offset = null)
 */
class ConfigRepository extends AbstractConfigRepository
{
    public function __construct(ManagerRegistry $registry, CacheManager $cacheManager)
    {
        parent::__construct($cacheManager, $registry, Config::class);
    }
}
