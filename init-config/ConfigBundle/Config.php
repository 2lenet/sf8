<?php

namespace App\Entity;

use Doctrine\ORM\Mapping as ORM;
use Lle\ConfigBundle\Contracts\ConfigInterface;
use Lle\ConfigBundle\Traits\ConfigTrait;

#[ORM\Entity(repositoryClass: ConfigRepository::class)]
class Config implements ConfigInterface
{
    use ConfigTrait;
}
