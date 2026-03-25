<?php

declare(strict_types=1);

namespace App\Entity;

use Lle\CredentialBundle\Entity\Group;
use Symfony\Component\Form\AbstractType;
use Symfony\Component\Form\FormBuilderInterface;

class UserType extends AbstractType
{
    public function buildForm(FormBuilderInterface $builder, array $options): void
    {
        $builder->add('username');
        $builder->add('email');
        $builder->add('prenom');
        $builder->add('nom');
        $builder->add('profil', null, [
            'class' => Group::class,
            'route' => 'app_crudit_group_autocomplete',
            'multiple' => false,
        ]);
    }

    public function getName(): string
    {
        return 'user_form';
    }
}
